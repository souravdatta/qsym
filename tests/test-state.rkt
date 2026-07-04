#lang racket

(require rackunit
         "../private/state.rkt")

(define h-factor (/ 1.0 (sqrt 2.0)))

;; Helper: construct a |+⟩ state manually.
(define (make-plus-state)
  (quantum-state 1 (vector->immutable-vector (vector h-factor h-factor))))

;; Helper: squared magnitude.
(define (prob a) (let ([m (magnitude a)]) (* m m)))

;; ---- zero-state ----

(test-case "zero-state: correct qubit count"
  (for ([n '(1 2 3 5)])
    (check-equal? (quantum-state-num-qubits (zero-state n)) n)))

(test-case "zero-state: amplitude 1 at index 0"
  (for ([n '(1 2 3)])
    (let ([s (zero-state n)])
      (check-= (prob (vector-ref (quantum-state-amplitudes s) 0)) 1.0 1e-9))))

(test-case "zero-state: amplitude 0 everywhere else"
  (for ([n '(1 2 3)])
    (let ([amps (quantum-state-amplitudes (zero-state n))])
      (for ([k (in-range 1 (vector-length amps))])
        (check-= (magnitude (vector-ref amps k)) 0.0 1e-9)))))

(test-case "zero-state: amplitudes vector is immutable"
  (let ([s (zero-state 2)])
    (check-exn exn:fail?
               (λ () (vector-set! (quantum-state-amplitudes s) 0 0+0i)))))

;; ---- basis-state ----

(test-case "basis-state: amplitude 1 at target index"
  (for ([k '(0 1 3 5 7)])
    (let ([s (basis-state 3 k)])
      (check-= (prob (vector-ref (quantum-state-amplitudes s) k)) 1.0 1e-9))))

(test-case "basis-state: amplitude 0 at non-target indices"
  (let ([s (basis-state 3 5)])
    (for ([k (in-range 8)]
          #:when (not (= k 5)))
      (check-= (magnitude (vector-ref (quantum-state-amplitudes s) k)) 0.0 1e-9))))

;; ---- state-probability ----

(test-case "state-probability: |0⟩ all in index 0"
  (check-= (state-probability (zero-state 1) 0) 1.0 1e-9)
  (check-= (state-probability (zero-state 1) 1) 0.0 1e-9))

(test-case "state-probability: |+⟩ has prob 0.5 at each index"
  (let ([plus (make-plus-state)])
    (check-= (state-probability plus 0) 0.5 1e-9)
    (check-= (state-probability plus 1) 0.5 1e-9)))

(test-case "state-probability: probabilities sum to 1 for any state"
  (for ([n '(1 2 3)])
    (let* ([s (zero-state n)]
           [total (for/sum ([k (in-range (expt 2 n))])
                    (state-probability s k))])
      (check-= total 1.0 1e-9))))

;; ---- qubit-probability ----

(test-case "qubit-probability: |0⟩ qubit 0"
  (let ([s (zero-state 1)])
    (check-= (qubit-probability s 0 0) 1.0 1e-9)
    (check-= (qubit-probability s 0 1) 0.0 1e-9)))

(test-case "qubit-probability: |+⟩ qubit 0"
  (let ([plus (make-plus-state)])
    (check-= (qubit-probability plus 0 0) 0.5 1e-9)
    (check-= (qubit-probability plus 0 1) 0.5 1e-9)))

(test-case "qubit-probability: 2-qubit |00⟩ both qubits"
  (let ([s (zero-state 2)])
    (check-= (qubit-probability s 0 0) 1.0 1e-9)
    (check-= (qubit-probability s 0 1) 0.0 1e-9)
    (check-= (qubit-probability s 1 0) 1.0 1e-9)
    (check-= (qubit-probability s 1 1) 0.0 1e-9)))

(test-case "qubit-probability: probabilities for each qubit sum to 1"
  (for ([n '(1 2 3)])
    (let ([s (zero-state n)])
      (for ([q (in-range n)])
        (check-= (+ (qubit-probability s q 0) (qubit-probability s q 1))
                 1.0
                 1e-9)))))

(test-case "qubit-probability: basis-state 3 5 (=101₂)"
  ;; Index 5 = 101₂: qubit 0 = 1, qubit 1 = 0, qubit 2 = 1.
  (let ([s (basis-state 3 5)])
    (check-= (qubit-probability s 0 1) 1.0 1e-9)
    (check-= (qubit-probability s 0 0) 0.0 1e-9)
    (check-= (qubit-probability s 1 0) 1.0 1e-9)
    (check-= (qubit-probability s 2 1) 1.0 1e-9)))

;; ---- state-normalized? ----

(test-case "state-normalized?: basis states are normalized"
  (for ([n '(1 2 3)])
    (for ([k (in-range (expt 2 n))])
      (check-true (state-normalized? (basis-state n k))))))

(test-case "state-normalized?: |+⟩ is normalized"
  (check-true (state-normalized? (make-plus-state))))

(test-case "state-normalized?: unnormalized state fails"
  (let ([bad (quantum-state 1 (vector->immutable-vector (vector 0.5+0i 0.5+0i)))])
    (check-false (state-normalized? bad))))

;; ---- state-~= ----

(test-case "state-~=: reflexivity"
  (let ([s (zero-state 3)])
    (check-true (state-~= s s))))

(test-case "state-~=: equal states"
  (check-true (state-~= (zero-state 3) (zero-state 3))))

(test-case "state-~=: different states"
  (check-false (state-~= (zero-state 2) (basis-state 2 1))))

(test-case "state-~=: different qubit count"
  (check-false (state-~= (zero-state 1) (zero-state 2))))

(test-case "state-~=: custom tolerance"
  (let* ([a (quantum-state 1 (vector->immutable-vector (vector 1.0+0i 0.0+0i)))]
         [b (quantum-state 1 (vector->immutable-vector (vector (+ 1.0 1e-10) 0.0+0i)))])
    (check-true  (state-~= a b 1e-9))
    (check-false (state-~= a b 1e-11))))

;; ---- convenience ----

(test-case "qubits = zero-state"
  (for ([n '(1 2 3)])
    (check-true (state-~= (qubits n) (zero-state n)))))

(test-case "q0 = single-qubit zero state"
  (check-true (state-~= q0 (zero-state 1))))
