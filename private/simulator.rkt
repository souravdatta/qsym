#lang racket/base

;; State-vector simulator: run-state and single-qubit gate-apply state helpers.
;;
;; The index-arithmetic kernels (apply-gate-kq/1q/2q, apply-item) are defined
;; in circuit.rkt and re-exported here so callers need only require one module.

(require "state.rkt"
         "gates.rkt"
         "circuit.rkt")

(provide
 apply-gate-1q
 apply-gate-2q
 apply-gate-kq
 run-state
 ;; single-qubit gate-apply helpers (state-level API for protocol code)
 gX gY gZ gH gS gT gTdg
 gRx gRy gRz)

;; run-state: execute a measurement-free circuit on an input state using
;; the index-arithmetic kernels.  Errors on circuits with measure/when-bit;
;; use run-shot (measurement.rkt) for those.
;;
;; initial-state defaults to |0…0⟩ when omitted.
(define (run-state circ [initial-state #f])
  (define n      (circuit-num-qubits circ))
  (define state0 (or initial-state (zero-state n)))
  (unless (= n (quantum-state-num-qubits state0))
    (error 'run-state "circuit has ~a qubits but state has ~a"
           n (quantum-state-num-qubits state0)))
  (when (ormap (lambda (item) (or (measure-at? item) (when-bit*? item)))
               (circuit-layers circ))
    (error 'run-state "circuit contains measurement; use run-shot"))
  (for/fold ([st state0])
            ([item (circuit-layers circ)])
    (apply-item item st)))

;; ---- single-qubit state helpers --------------------------------------------
;;
;; Apply a standard gate to qubit 0 of a 1-qubit state.
;; Useful for protocol code (BB84, teleportation payload prep) that works
;; qubit-by-qubit.

(define (gX   state) (apply-gate-1q (gate-matrix X)   0 state))
(define (gY   state) (apply-gate-1q (gate-matrix Y)   0 state))
(define (gZ   state) (apply-gate-1q (gate-matrix Z)   0 state))
(define (gH   state) (apply-gate-1q (gate-matrix H)   0 state))
(define (gS   state) (apply-gate-1q (gate-matrix S)   0 state))
(define (gT   state) (apply-gate-1q (gate-matrix T)   0 state))
(define (gTdg state) (apply-gate-1q (gate-matrix Tdg) 0 state))

(define (gRx theta state) (apply-gate-1q (gate-matrix (RX theta)) 0 state))
(define (gRy theta state) (apply-gate-1q (gate-matrix (RY theta)) 0 state))
(define (gRz theta state) (apply-gate-1q (gate-matrix (RZ theta)) 0 state))
