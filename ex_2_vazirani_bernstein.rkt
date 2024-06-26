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

(define oracle2 (list
                (def-layer (cx 0 5))
                (def-layer (cx 1 5))
                (def-layer (cx 4 5))))

;; helper function
(define (hgates n)
  (for/list ([i (range n)])
    (list 'h i)))

(define c (def-circuit 6
              (def-layer (x 5))
              (list->layer (hgates 6))
              oracle2 ;; the secret oracle that encode a string
              (list->layer (hgates 6))))

(define sim (sv-simulator c))
(plot-histogram
 (counts (sim (qubits 6)))) ; This should reveal 1<secret string from oracle - 10011> with max prob

(draw-circuit c)

;; |                 | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |                 | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |                 | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |                 | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |                 | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |  x              | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
