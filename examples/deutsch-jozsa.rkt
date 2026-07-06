#lang racket

;; Deutsch–Jozsa: determine in one query whether f:{0,1}^n -> {0,1} is
;; constant (same output for all inputs) or balanced (0 for exactly half).
;; Measuring the first n qubits: all-0 -> constant, any-1 -> balanced.

(require qsym)

;; Oracle for f(x) = XOR of all input bits (balanced).
;; CX from each input qubit i to ancilla (qubit n).
(define (oracle-balanced n)
  (for/list ([i (in-range n)])
    (at CX i n)))

;; Oracle for constant f = 1 (flip ancilla unconditionally).
(define (oracle-constant1 n)
  (list (at X n)))

;; Oracle for constant f = 0 (identity; empty list of layers).
(define (oracle-constant0 n) '())

(define (dj-circuit oracle n)
  (make-circuit
   (append
    ;; Initialize ancilla to |-⟩ = (|0⟩-|1⟩)/√2.
    (list (append (make-list n ID) (list X)))
    (list (make-list (+ n 1) H))
    (oracle n)
    (list (append (make-list n H) (list ID))))
   #:qubits (+ n 1)))

(define n 4)

(define (dj-result oracle name)
  (define circ (dj-circuit oracle n))
  (define st (circ (qubits (circuit-num-qubits circ))))
  (define c (counts st #:shots 256 #:seed 1))
  (define keys (hash-keys c))
  ;; The input qubits are the n LSBs of the measured bit-string (rightmost n chars).
  ;; Constant: only one key, input portion = "000...0".
  ;; Balanced: input portion has at least one '1'.
  (define all-zero?
    (for/and ([k keys])
      (define input-bits (substring k 1))  ; drop ancilla (MSB)
      (string=? input-bits (make-string n #\0))))
  (displayln (format "~a oracle -> ~a" name (if all-zero? "CONSTANT" "BALANCED"))))

(dj-result oracle-constant0 "constant-0")
(dj-result oracle-constant1 "constant-1")
(dj-result oracle-balanced  "balanced (XOR)")
