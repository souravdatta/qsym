#lang racket/base

;; State-vector simulator: index-arithmetic gate kernels and run-state.
;;
;; Gate application is O(2^n) per gate via direct index arithmetic — not O(4^n)
;; tensor-product expansion.  All mutation is local: a fresh mutable vector is
;; built per call, filled from the immutable input amplitudes, then frozen.
;;
;; Qubit index convention (little-endian, Qiskit-compatible):
;;   qubit i corresponds to bit i of the state-vector index.
;;   For (apply-gate-2q mat t0 t1 ...): local qubit 0 of the gate = register
;;   qubit t0, local qubit 1 = register qubit t1, etc.

(require math/matrix
         racket/vector
         "state.rkt"
         "gates.rkt"
         "circuit.rkt")

(provide
 apply-gate-1q
 apply-gate-2q
 apply-gate-kq
 run-state)

;; ---- general k-qubit kernel ------------------------------------------------

;; apply-gate-kq: apply a k-qubit gate to a state via index arithmetic.
;;
;; mat    : 2^k × 2^k unitary matrix (gate in the local-qubit basis)
;; qs     : list of k register-qubit indices; position i = local qubit i
;; state  : input quantum-state
;; Returns a new quantum-state with the gate applied.
;;
;; Algorithm: partition the 2^n state indices into groups of 2^k by their
;; "base" — the index with bits qs[0..k-1] all cleared.  Within each group
;; the gate matrix is applied to the 2^k amplitude sub-vector formed by
;; setting those bits.  Groups are disjoint so the mutable output vector
;; is safe: each index is written exactly once.
(define (apply-gate-kq mat qs state)
  (define n     (quantum-state-num-qubits state))
  (define N     (expt 2 n))
  (define k     (length qs))
  (define K     (expt 2 k))
  (define amps  (quantum-state-amplitudes state))
  (define steps (list->vector (map (lambda (q) (expt 2 q)) qs)))
  ;; mask: OR of all 2^qi — used to test whether base has all target bits clear
  (define mask  (for/fold ([m 0]) ([s (in-vector steps)]) (bitwise-ior m s)))
  (define out   (vector-copy amps))   ; mutable; filled from amps, never read back
  (for ([base (in-range N)]
        #:when (= (bitwise-and base mask) 0))
    ;; idx-vec[s] = full index for sub-index s in this group.
    ;; sub-index s encodes which of the k target qubits are 1:
    ;;   bit i of s == 1  ->  set bit qs[i] in the full index.
    (define idx-vec
      (for/vector ([s (in-range K)])
        (for/fold ([idx base])
                  ([step (in-vector steps)] [pos (in-naturals)])
          (+ idx (* step (bitwise-and (arithmetic-shift s (- pos)) 1))))))
    ;; old-vals[c] = amplitude at full index idx-vec[c]  (read from amps, not out)
    (define old-vals
      (for/vector ([c (in-range K)])
        (vector-ref amps (vector-ref idx-vec c))))
    ;; new amplitude for each output sub-index r: row r of gate matrix × old-vals
    (for ([r (in-range K)])
      (define new-val
        (for/fold ([acc 0+0i])
                  ([c (in-range K)])
          (+ acc (* (matrix-ref mat r c) (vector-ref old-vals c)))))
      (vector-set! out (vector-ref idx-vec r) new-val)))
  (quantum-state n (vector->immutable-vector out)))

;; ---- specialized 1-qubit and 2-qubit kernels --------------------------------

;; apply-gate-1q: apply a 2×2 gate matrix to qubit t of state.
(define (apply-gate-1q mat t state)
  (apply-gate-kq mat (list t) state))

;; apply-gate-2q: apply a 4×4 gate matrix to (t0, t1) of state.
;; t0 = local qubit 0 (e.g. control), t1 = local qubit 1 (e.g. target).
(define (apply-gate-2q mat t0 t1 state)
  (apply-gate-kq mat (list t0 t1) state))

;; ---- run-state --------------------------------------------------------------

;; run-state: execute a measurement-free circuit on an input state using the
;; index-arithmetic kernels.  Errors on circuits containing measure/when-bit;
;; use run-shot (Phase 4) for those.
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

;; apply-item: dispatch one layer item to the appropriate kernel.
(define (apply-item item state)
  (cond
    ;; Positional list: each entry is a 1-qubit gate on qubit i.
    ;; Skip identity gates (name = 'id) for efficiency.
    [(list? item)
     (for/fold ([st state])
               ([g item] [i (in-naturals)])
       (if (eq? (gate-name g) 'id)
           st
           (apply-gate-1q (gate-matrix g) i st)))]
    ;; Bare gate: applied to qubits 0..arity-1
    [(gate? item)
     (apply-gate-kq (gate-matrix item)
                    (for/list ([i (in-range (gate-arity item))]) i)
                    state)]
    ;; Gate at explicit qubit indices
    [(gate-at? item)
     (apply-gate-kq (gate-matrix (gate-at-gate item))
                    (gate-at-qubits item)
                    state)]
    [else
     (error 'run-state "unrecognized layer item: ~a" item)]))
