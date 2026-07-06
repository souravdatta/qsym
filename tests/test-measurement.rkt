#lang racket/base

(require rackunit
         "../private/linalg.rkt"
         "../private/state.rkt"
         "../private/gates.rkt"
         "../private/circuit.rkt"
         "../private/measurement.rkt")

;; ---- helper ----------------------------------------------------------------

(define tol 1e-9)

(define (approx? a b) (< (abs (- a b)) 1e-6))

;; Bell state: (|00⟩ + |11⟩) / √2
(define bell-circuit
  (make-circuit (list (list H ID) CX) #:qubits 2))

(define bell-state
  (bell-circuit (qubits 2)))

;; ---- probabilities ---------------------------------------------------------

(test-case "probabilities: |+⟩ has 0.5 for each outcome"
  (define plus-state (apply-gate-1q (gate-matrix H) 0 q0))
  (define p (probabilities plus-state))
  (check-true  (hash-has-key? p "0"))
  (check-true  (hash-has-key? p "1"))
  (check-true  (approx? (hash-ref p "0") 0.5))
  (check-true  (approx? (hash-ref p "1") 0.5)))

(test-case "probabilities: |0⟩ has only outcome '0'"
  (define p (probabilities q0))
  (check-equal? (hash-count p) 1)
  (check-true   (approx? (hash-ref p "0") 1.0)))

(test-case "probabilities: Bell state has outcomes '00' and '11'"
  (define p (probabilities bell-state))
  (check-equal? (hash-count p) 2)
  (check-true (hash-has-key? p "00"))
  (check-true (hash-has-key? p "11"))
  (check-true (approx? (hash-ref p "00") 0.5))
  (check-true (approx? (hash-ref p "11") 0.5)))

;; ---- marginal-distribution -------------------------------------------------

(test-case "marginal-distribution: Bell state, qubit 0"
  (define pd (marginal-distribution bell-state '(0)))
  (check-true (approx? (vector-ref pd 0) 0.5))  ; P(q0=0) = 0.5
  (check-true (approx? (vector-ref pd 1) 0.5))) ; P(q0=1) = 0.5

(test-case "marginal-distribution: Bell state, qubits 0 and 1 jointly"
  (define pd (marginal-distribution bell-state '(0 1)))
  ; P(q0=0,q1=0) = 0.5, P(q0=1,q1=1) = 0.5, others = 0
  (check-true (approx? (vector-ref pd 0) 0.5))  ; sub-idx 0: q0=0,q1=0
  (check-true (approx? (vector-ref pd 1) 0.0))  ; sub-idx 1: q0=1,q1=0
  (check-true (approx? (vector-ref pd 2) 0.0))  ; sub-idx 2: q0=0,q1=1
  (check-true (approx? (vector-ref pd 3) 0.5))) ; sub-idx 3: q0=1,q1=1

;; ---- collapse-state --------------------------------------------------------

(test-case "collapse: Bell state, qubit 0 measured as 0 -> |00⟩"
  (define collapsed (collapse-state bell-state (list (cons 0 0))))
  (check-true (state-normalized? collapsed))
  ; After collapse: q1 must be 0 with probability 1
  (check-true (approx? (qubit-probability collapsed 0 0) 1.0))
  (check-true (approx? (qubit-probability collapsed 1 0) 1.0)))

(test-case "collapse: Bell state, qubit 0 measured as 1 -> |11⟩"
  (define collapsed (collapse-state bell-state (list (cons 0 1))))
  (check-true (state-normalized? collapsed))
  (check-true (approx? (qubit-probability collapsed 0 1) 1.0))
  (check-true (approx? (qubit-probability collapsed 1 1) 1.0)))

(test-case "collapse: Bell state, both qubits measured as 0 -> |00⟩"
  (define collapsed (collapse-state bell-state (list (cons 0 0) (cons 1 0))))
  (check-true (state-normalized? collapsed))
  (check-true (approx? (state-probability collapsed 0) 1.0)))

;; ---- counts ----------------------------------------------------------------

(test-case "counts: Bell state gives only '00' and '11'"
  (define c (counts bell-state #:shots 2000 #:seed 42))
  (check-true (hash-has-key? c "00"))
  (check-true (hash-has-key? c "11"))
  (check-equal? (hash-count c) 2)
  (check-equal? (+ (hash-ref c "00") (hash-ref c "11")) 2000))

(test-case "counts: deterministic with same seed"
  (define c1 (counts bell-state #:shots 500 #:seed 99))
  (define c2 (counts bell-state #:shots 500 #:seed 99))
  (check-equal? c1 c2))

(test-case "counts: |0⟩ always gives '0'"
  (define c (counts q0 #:shots 100 #:seed 1))
  (check-equal? (hash-ref c "0") 100))

(test-case "counts: |1⟩ always gives '1'"
  (define one-state (apply-gate-1q (gate-matrix X) 0 q0))
  (define c (counts one-state #:shots 100 #:seed 1))
  (check-equal? (hash-ref c "1") 100))

(test-case "counts: |+⟩ state sums to shots"
  (define plus-state (apply-gate-1q (gate-matrix H) 0 q0))
  (define c (counts plus-state #:shots 4096 #:seed 7))
  (check-equal? (+ (hash-ref c "0" 0) (hash-ref c "1" 0)) 4096))

;; ---- run-shot --------------------------------------------------------------

(test-case "run-shot: no measurement circuit returns correct state and empty cbits"
  (define circ (make-circuit (list (list H ID) CX) #:qubits 2))
  (define-values (st cb) (run-shot circ (qubits 2)))
  (check-true (state-~= st bell-state))
  (check-equal? (vector->list cb) '()))

(test-case "run-shot: single measurement on |+⟩ gives 0 or 1"
  (define circ (make-circuit (list (at H 0) (measure 0)) #:qubits 1 #:clbits 1))
  (define rng (make-pseudo-random-generator))
  (parameterize ([current-pseudo-random-generator rng]) (random-seed 0))
  (for ([_ (in-range 20)])
    (define-values (_ cb) (run-shot circ q0 #:rng rng))
    (check-true (or (= (vector-ref cb 0) 0) (= (vector-ref cb 0) 1)))))

(test-case "run-shot: Bell measurement gives only 00 or 11"
  (define bell-measure
    (make-circuit (list (list H ID) CX (measure 0 1)) #:qubits 2 #:clbits 2))
  (define rng (make-pseudo-random-generator))
  (parameterize ([current-pseudo-random-generator rng]) (random-seed 5))
  (for ([_ (in-range 50)])
    (define-values (_ cb) (run-shot bell-measure (qubits 2) #:rng rng))
    (check-true (or (equal? (vector->list cb) '(0 0))
                    (equal? (vector->list cb) '(1 1))))))

;; ---- run-shots -------------------------------------------------------------

(test-case "run-shots: Bell measurement gives only '00' and '11'"
  (define bell-measure
    (make-circuit (list (list H ID) CX (measure 0 1)) #:qubits 2 #:clbits 2))
  (define c (run-shots bell-measure (qubits 2) #:shots 2000 #:seed 42))
  (check-equal? (hash-count c) 2)
  (check-true (hash-has-key? c "00"))
  (check-true (hash-has-key? c "11"))
  (check-equal? (+ (hash-ref c "00") (hash-ref c "11")) 2000))

(test-case "run-shots: deterministic with same seed"
  (define bell-measure
    (make-circuit (list (list H ID) CX (measure 0 1)) #:qubits 2 #:clbits 2))
  (define c1 (run-shots bell-measure (qubits 2) #:shots 200 #:seed 77))
  (define c2 (run-shots bell-measure (qubits 2) #:shots 200 #:seed 77))
  (check-equal? c1 c2))

;; ---- when-bit (classical conditioning) ------------------------------------

(test-case "when-bit: X applied only when clbit is 1"
  ; Circuit: measure qubit 0, then apply X to qubit 1 if clbit 0 = 1.
  ; Start with qubit 0 in |1⟩, qubit 1 in |0⟩.
  ; Measurement always gives clbit 0 = 1, so X is always applied.
  (define circ
    (make-circuit
     (list (at X 0)
           (measure 0)
           (when-bit 0 1 (at X 1)))
     #:qubits 2 #:clbits 1))
  (define rng (make-pseudo-random-generator))
  (parameterize ([current-pseudo-random-generator rng]) (random-seed 0))
  (for ([_ (in-range 10)])
    (define-values (st _) (run-shot circ (qubits 2) #:rng rng))
    ; q1 should be |1⟩ (X was applied)
    (check-true (approx? (qubit-probability st 1 1) 1.0))))

(test-case "when-bit: X NOT applied when clbit is 0"
  ; Qubit 0 in |0⟩, measure -> clbit 0 = 0.  X on qubit 1 should not fire.
  (define circ
    (make-circuit
     (list (measure 0)
           (when-bit 0 1 (at X 1)))
     #:qubits 2 #:clbits 1))
  (define rng (make-pseudo-random-generator))
  (parameterize ([current-pseudo-random-generator rng]) (random-seed 0))
  (for ([_ (in-range 10)])
    (define-values (st _) (run-shot circ (qubits 2) #:rng rng))
    ; q1 should remain |0⟩
    (check-true (approx? (qubit-probability st 1 0) 1.0))))
