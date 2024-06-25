#lang racket

;; Copyright Sourav Datta (soura.jagat@gmail.com)
;; You should have received a copy of the LICENSE along with this code
;; in the repository. If not refer to
;; https://github.com/souravdatta/qsym/blob/main/LICENSE

(require "qsym.rkt")
(require "qlang.rkt")


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

(plot-histogram
 (counts r #:shots 2000)) ;; 110011 with close 100% probability

;; Using Qlang
(define c (def-circuit 6
              (def-layer (x 5))
              (def-layer
                (h 0)
                (h 1)
                (h 2)
                (h 3)
                (h 4)
                (h 5))
              ;; begin oracle
              (def-layer (cx 0 5))
              (def-layer (cx 1 5))
              (def-layer (cx 4 5))
              ;; end oracle
              (def-layer
                (h 0)
                (h 1)
                (h 2)
                (h 3)
                (h 4)
                (h 5))))

(define sim (sv-simulator c))
(plot-histogram
 (counts (sim (qubits 6))))

(draw-circuit c)
;; 
;; |  i              | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |  i              | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |  i              | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |  i              | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |  i              | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |  x              | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
