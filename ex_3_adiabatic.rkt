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


;; Adiabatic circuit |-> --> |1>

(define a-circuit (make-circuit (append
                                 (list X
                                       H)
                                 (adiabatic-gates 30))))

(plot-histogram (counts (a-circuit q0)))


;; Adiabatic circuit 2 |+> --> |0>

(define a-circuit2 (make-circuit (cons
                                  H
                                  (adiabatic-gates 30))))

(plot-histogram (counts (a-circuit2 q0)))

;; Using qlang

(define (adiabatic-layers angle)
  (reverse
   (for/fold ([a '()])
             ([i (range 0 1 0.001)])
     (cons (def-layer [(rz (* angle i)) 0])
           (cons (def-layer [(rx (* angle (- 1 i))) 0]) a)))))

(define circuit (def-circuit 1
                  (def-layer
                    (x 0))
                  (def-layer
                    (h 0))
                  (adiabatic-layers 30)))

(define simulator (sv-simulator circuit))

(plot-histogram (counts (simulator q0)))

;; (draw-circuit circuit)

