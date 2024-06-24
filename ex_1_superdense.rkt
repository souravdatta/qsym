#lang racket

;; Copyright Sourav Datta (soura.jagat@gmail.com)
;; You should have received a copy of the LICENSE along with this code
;; in the repository. If not refer to
;; https://github.com/souravdatta/qsym/blob/main/LICENSE

(require "qsym.rkt")
(require "qlang.rkt")

;; Super dense coding

;;     1   2       3,4    5        6
;; -> [H] ->   -> [?] -> -> -> -> [H]  ->
;;         |              |
;; -> ->  [CX] -> ->  -> [CX] -> -> -> ->

(define circuit1
  (make-circuit
   (list (list H
               I2)    ;; 1
         CX              ;; 2
         (list Z
               I2)    ;; 3,4
         CX              ;; 5
         (list H
               I2)))) ;; 6

(define input (qubits 2))

(counts (circuit1 input)) ;; decoded as (0 1) -> qiskit endian!
(plot-histogram (counts (circuit1 input)))


(define circuit2
  (make-circuit
   (list (list H
               I2)    ;; 1
         CX              ;; 2
         (list X
               I2)    ;; 3,4
         CX              ;; 5
         (list H
               I2)))) ;; 6

(counts (circuit2 input)) ;; decoded as (1 0) -> qiskit endian!
(plot-histogram (counts (circuit2 input)))


(define circuit3
  (make-circuit
   (list (list H
               I2)    ;; 1
         CX              ;; 2
         (list Z
               I2)
         (list X
               I2)    ;; 3,4
         CX              ;; 5
         (list H
               I2)))) ;; 6

(counts (circuit3 input)) ;; decoded as (1 1) -> qiskit endian!
(plot-histogram (counts (circuit3 input)))


(define circuit4
  (make-circuit
   (list (list H
               I2)    ;; 1
         CX              ;; 2
         (list I2
               I2)    ;; 3,4
         CX              ;; 5
         (list H
               I2)))) ;; 6

(counts (circuit4 input)) ;; decoded as (0 0) -> qiskit endian!
(plot-histogram (counts (circuit4 input)))

;; Using qlang

;; Using qlang

(define c1 (def-circuit 2
             (def-layer (h 0))
             (def-layer (cx 0 1))
             (def-layer (z 0))
             (def-layer (cx 0 1))
             (def-layer (h 0))))

(draw-circuit c1)
(plot-histogram (counts ((sv-simulator c1) (qubits 2))))
