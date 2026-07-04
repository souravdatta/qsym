#lang racket/base

;; Quantum state representation and fundamental state operations.
;;
;; A quantum state is an n-qubit pure state stored as an immutable vector
;; of 2^n complex amplitudes.  Indexing is little-endian: bit i of index k
;; is the value of qubit i.  So index 0 = |0…0⟩, index 1 = qubit-0 flipped, etc.

(provide
 (struct-out quantum-state)
 zero-state
 basis-state
 state-probability
 qubit-probability
 state-normalized?
 state-~=
 qubits
 q0)

;; Quantum state: num-qubits qubits, 2^num-qubits complex amplitudes.
(struct quantum-state (num-qubits amplitudes) #:transparent)

;; |0…0⟩: amplitude 1 at index 0, 0 everywhere else.
(define (zero-state n)
  (let ([amps (make-vector (expt 2 n) 0+0i)])
    (vector-set! amps 0 1.0+0i)
    (quantum-state n (vector->immutable-vector amps))))

;; |k⟩: amplitude 1 at index k, 0 everywhere else.
(define (basis-state n k)
  (let ([amps (make-vector (expt 2 n) 0+0i)])
    (vector-set! amps k 1.0+0i)
    (quantum-state n (vector->immutable-vector amps))))

;; Probability of measuring basis state k: |ψ[k]|².
(define (state-probability state k)
  (let ([m (magnitude (vector-ref (quantum-state-amplitudes state) k))])
    (* m m)))

;; Marginal probability that qubit q alone measures as value v (0 or 1).
;; Sums |ψ[k]|² over all k where bit q of k equals v.
(define (qubit-probability state q v)
  (let ([n    (quantum-state-num-qubits state)]
        [amps (quantum-state-amplitudes state)])
    (for/fold ([prob 0.0])
              ([k (in-range (expt 2 n))]
               #:when (= (bitwise-and (arithmetic-shift k (- q)) 1) v))
      (let ([m (magnitude (vector-ref amps k))])
        (+ prob (* m m))))))

;; True iff the sum of squared amplitudes is within tol of 1.
(define (state-normalized? state [tol 1e-9])
  (let ([total (for/fold ([s 0.0])
                         ([a (in-vector (quantum-state-amplitudes state))])
                 (let ([m (magnitude a)])
                   (+ s (* m m))))])
    (< (abs (- total 1.0)) tol)))

;; True iff s1 and s2 have the same qubit count and matching amplitudes
;; element-wise within tolerance tol.
(define (state-~= s1 s2 [tol 1e-9])
  (and (= (quantum-state-num-qubits s1) (quantum-state-num-qubits s2))
       (let ([a1 (quantum-state-amplitudes s1)]
             [a2 (quantum-state-amplitudes s2)])
         (for/and ([i (in-range (vector-length a1))])
           (< (magnitude (- (vector-ref a1 i) (vector-ref a2 i))) tol)))))

;; Convenience: n-qubit all-zero state (same as zero-state).
(define (qubits n) (zero-state n))

;; Single-qubit zero state |0⟩.
(define q0 (zero-state 1))
