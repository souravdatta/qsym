#lang racket

;; Copyright Sourav Datta (soura.jagat@gmail.com)
;; You should have received a copy of the LICENSE along with this code
;; in the repository. If not refer to
;; https://github.com/souravdatta/qsym/blob/main/LICENSE


(require "qsym.rkt")

(define (adiabatic-gates angle)
  (flatten
   (for/list ([i (range 0 1 0.001)])
     (list
      (Rx (* angle (- 1 i)))
      (Rz (* angle i))))))

(define simple-circuit (make-circuit (list
                                      X
                                      H
                                      (Rx 30))))

(plot-histogram (counts (simple-circuit q0)))


;; Adiabatic circuit

(define a-circuit (make-circuit (append
                                 (list X
                                       H)
                                 (adiabatic-gates 30))))

(plot-histogram (counts (a-circuit q0)))
