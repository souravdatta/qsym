#lang racket

;; Bernstein–Vazirani: recover a secret bit-string s in one query.
;; The oracle computes f(x) = s · x (inner product mod 2) on an ancilla qubit.
;; Applying H before and after the oracle reads out s directly.

(require qsym)

;; Oracle for secret bit-vector: CX from input qubit i to ancilla (qubit n)
;; for each bit i where secret[i]=1.
(define (oracle secret)
  (define n (length secret))
  (for/list ([b secret] [i (in-naturals)]
             #:when (= b 1))
    (at CX i n)))

;; n = number of input qubits, ancilla = qubit n (initialized to |1⟩ via X).
(define (bv-circuit secret)
  (define n (length secret))
  (make-circuit
   (append (list (append (make-list n ID) (list X))) ; set ancilla to |1⟩
           (list (make-list (+ n 1) H))               ; H on all qubits
           (oracle secret)
           (list (append (make-list n H) (list ID)))) ; H on input qubits
   #:qubits (+ n 1)))

(define secret '(1 1 0 0 1))

(define circ (bv-circuit secret))
(define final-state (circ (qubits (circuit-num-qubits circ))))

(displayln (format "Secret:   ~a" secret))
(displayln "Counts (should be a single bit-string matching the secret):")
;; The input qubits (0..n-1) should all be deterministic, matching the secret.
;; Ancilla qubit (MSB in the bit string) ends in superposition — ignore it.
(define c (counts final-state #:shots 512 #:seed 1))
(for ([(k v) (in-hash c)])
  (displayln (format "  ~a : ~a" k v)))
