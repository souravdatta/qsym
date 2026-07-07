#lang racket/base

;; qsym — quantum state-vector simulation library.
;; This module is the single entry point: (require qsym).
;;
;; Endianness: LITTLE-ENDIAN, Qiskit-compatible.
;;   Qubit 0 is the least-significant bit of a basis-state index.
;;   Bit strings are printed MSB-first so qubit 0 is the rightmost character.
;;   (at CX 0 1) means qubit 0 = CONTROL, qubit 1 = TARGET.

(require racket/contract
         math/matrix
         pict
         "private/linalg.rkt"
         "private/state.rkt"
         "private/gates.rkt"
         "private/circuit.rkt"
         "private/simulator.rkt"
         "private/measurement.rkt"
         "private/plot.rkt"
         "private/draw-text.rkt"
         "private/draw-pict.rkt"
         "private/bloch.rkt")

;; ---- struct re-exports (no contract-out wrapper for structs) ----------------

(provide
 (struct-out quantum-state)
 (struct-out gate)
 (struct-out gate-at)
 (struct-out measure-at)
 (struct-out when-bit*)
 (struct-out circuit))

;; ---- contract helpers -------------------------------------------------------
;; nat/c is not in racket/base; define a local flat contract.
(define nat/c (and/c exact-integer? (>=/c 0)))

;; ---- constant gate values ---------------------------------------------------
;; These are gate? values, not functions; provide without contract.

(provide
 ;; 1-qubit
 ID X Y Z H S Sdg T Tdg
 ;; 2-qubit
 CX CY CZ CH SWAP
 ;; 3-qubit
 CCX CSWAP
 ;; initial state convenience
 q0)

;; ---- single-qubit state-modifier shorthands (no params) --------------------

(provide gX gY gZ gH gS gT gTdg)

;; ---- contracted functions ---------------------------------------------------

(provide
 (contract-out

  ;; ── linalg ──────────────────────────────────────────────────────────────
  [tensor-product         (-> matrix? matrix? matrix?)]
  [matrix-~=              (->* (matrix? matrix?) (real?) boolean?)]
  [matrix-adjoint         (-> matrix? matrix?)]
  [matrix-unitary?        (->* (matrix?) (real?) boolean?)]
  [fourier-matrix         (-> exact-positive-integer? matrix?)]
  [inverse-fourier-matrix (-> exact-positive-integer? matrix?)]
  [index->bits            (-> nat/c exact-positive-integer?
                              (listof (integer-in 0 1)))]
  [bits->index            (-> (listof (integer-in 0 1)) nat/c)]
  [index->bit-string      (-> exact-positive-integer? nat/c string?)]

  ;; ── state ───────────────────────────────────────────────────────────────
  [zero-state         (-> exact-positive-integer? quantum-state?)]
  [basis-state        (-> exact-positive-integer? nat/c quantum-state?)]
  [state-probability  (-> quantum-state? nat/c real?)]
  [qubit-probability  (-> quantum-state? nat/c (integer-in 0 1) real?)]
  [state-normalized?  (-> quantum-state? boolean?)]
  [state-~=           (-> quantum-state? quantum-state? boolean?)]
  [qubits             (-> exact-positive-integer? quantum-state?)]

  ;; ── gates ───────────────────────────────────────────────────────────────
  [RX  (-> real? gate?)]
  [RY  (-> real? gate?)]
  [RZ  (-> real? gate?)]
  [P   (-> real? gate?)]
  [U   (-> real? real? real? gate?)]
  [CP  (-> real? gate?)]
  [CRX (-> real? gate?)]
  [matrix->gate  (-> symbol? matrix? gate?)]
  [gate-inverse  (-> gate? gate?)]
  [controlled    (-> gate? gate?)]

  ;; ── circuit ─────────────────────────────────────────────────────────────
  ;; at: gate followed by one qubit index per arity
  [at       (->* (gate?) () #:rest (listof nat/c) gate-at?)]
  ;; measure: integers or (list q c) pairs
  [measure  (->* () () #:rest list? measure-at?)]
  [when-bit (-> nat/c (integer-in 0 1) any/c when-bit*?)]
  [make-circuit
   (->* (list?)
        (#:qubits  (or/c #f exact-positive-integer?)
         #:clbits  nat/c)
        circuit?)]
  [circuit-append   (-> circuit? circuit? circuit?)]
  [circuit-repeat   (-> circuit? exact-positive-integer? circuit?)]
  [circuit-inverse  (-> circuit? circuit?)]
  [circuit->gate    (-> symbol? circuit? gate?)]
  [circuit->matrix  (-> circuit? matrix?)]
  [qft              (-> exact-positive-integer? circuit?)]
  [inverse-qft      (-> exact-positive-integer? circuit?)]
  [t*               (-> quantum-state? quantum-state? quantum-state?)]

  ;; ── simulator ───────────────────────────────────────────────────────────
  [apply-gate-1q  (-> matrix? nat/c quantum-state? quantum-state?)]
  [apply-gate-2q  (-> matrix? nat/c nat/c quantum-state? quantum-state?)]
  [apply-gate-kq  (-> matrix? (listof nat/c) quantum-state? quantum-state?)]
  [run-state      (-> circuit? quantum-state? quantum-state?)]
  [gRx  (-> real? quantum-state? quantum-state?)]
  [gRy  (-> real? quantum-state? quantum-state?)]
  [gRz  (-> real? quantum-state? quantum-state?)]

  ;; ── measurement ─────────────────────────────────────────────────────────
  [marginal-distribution
   (-> quantum-state? (listof nat/c) (vectorof real?))]
  [collapse-state
   (-> quantum-state? (listof (cons/c nat/c (integer-in 0 1))) quantum-state?)]
  [run-shot
   (->* (circuit?)
        ((or/c quantum-state? #f) #:rng any/c)
        (values quantum-state? vector?))]
  [counts
   (->* (quantum-state?)
        (#:shots exact-positive-integer?
         #:seed  (or/c #f exact-positive-integer?))
        hash?)]
  [run-shots
   (->* (circuit?)
        ((or/c quantum-state? #f)
         #:shots exact-positive-integer?
         #:seed  (or/c #f exact-positive-integer?))
        hash?)]
  [probabilities  (-> quantum-state? hash?)]

  ;; ── plot ────────────────────────────────────────────────────────────────
  [plot-histogram          (->* (hash?) (string?) any)]
  [plot-state-probabilities (->* (quantum-state?) (string?) any)]

  ;; ── draw-text ────────────────────────────────────────────────────────────
  [circuit->text   (-> circuit? string?)]
  [print-circuit   (-> circuit? void?)]
  [assign-columns  (-> circuit? list?)]
  [item-wire-span  (-> any/c exact-positive-integer?
                       (values nat/c nat/c))]
  [gate-label      (-> gate? string?)]

  ;; ── draw-pict ────────────────────────────────────────────────────────────
  [circuit->pict   (-> circuit? pict?)]

  ;; ── bloch ────────────────────────────────────────────────────────────────
  [qubit-density-matrix  (-> quantum-state? nat/c matrix?)]
  [bloch-vector          (-> quantum-state? nat/c (listof real?))]
  [bloch-pict            (->* (quantum-state?) (nat/c #:size positive?) pict?)]
  [bloch-pict*           (->* (quantum-state?) (#:size positive?) pict?)]))
