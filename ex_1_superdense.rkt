#lang racket

(require "qsym.rkt")

;; Super dense coding

;;     1   2       3,4    5        6
;; -> [H] ->   -> [?] -> -> -> -> [H]  ->
;;         |              |
;; -> ->  [CX] -> ->  -> [CX] -> -> -> ->

(define circuit1
  (make-circuit
   (list (list H
               (I 2))    ;; 1
         CX              ;; 2
         (list Z
               (I 2))    ;; 3,4
         CX              ;; 5
         (list H
               (I 2))))) ;; 6

(define input (qubits 2))

(counts (circuit1 input)) ;; decoded as (0 1) -> qiskit endian!


(define circuit2
  (make-circuit
   (list (list H
               (I 2))    ;; 1
         CX              ;; 2
         (list X
               (I 2))    ;; 3,4
         CX              ;; 5
         (list H
               (I 2))))) ;; 6

(counts (circuit2 input)) ;; decoded as (1 0) -> qiskit endian!


(define circuit3
  (make-circuit
   (list (list H
               (I 2))    ;; 1
         CX              ;; 2
         (list Z
               (I 2))
         (list X
               (I 2))    ;; 3,4
         CX              ;; 5
         (list H
               (I 2))))) ;; 6

(counts (circuit3 input)) ;; decoded as (1 1) -> qiskit endian!


(define circuit4
  (make-circuit
   (list (list H
               (I 2))    ;; 1
         CX              ;; 2
         (list (I 2)
               (I 2))    ;; 3,4
         CX              ;; 5
         (list H
               (I 2))))) ;; 6

(counts (circuit4 input)) ;; decoded as (0 0) -> qiskit endian!
