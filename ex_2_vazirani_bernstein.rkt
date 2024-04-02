#lang racket

(require "qsym.rkt")

;; Oracle for 10011
(define oracle (gate-matrix 6
                            (list
                             (list '(0 5)
                                   cnot-f)
                             (list '(1 5)
                                   cnot-f)
                             (list '(4 5)
                                   cnot-f))))

(define cirq
  (make-circuit (list
                 (list (I 2)
                       (I 2)
                       (I 2)
                       (I 2)
                       (I 2)
                       X)
                 (make-list 6 H)
                 oracle
                 (make-list 6 H))))


(define input (qubits 6))

(define r (cirq input))

(counts r #:shots 2000) ;; 110011 with close 100% probability
