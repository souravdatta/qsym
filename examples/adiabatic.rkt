#lang racket

;; Adiabatic evolution demo (1 qubit).
;; Slowly rotates from |+⟩ (Hx ground state) to |0⟩ (Hz ground state)
;; by sweeping the Hamiltonian angle from Rx-dominated to Rz-dominated.

(require qsym)

;; Returns a flat list of alternating Rx/Rz gate layers, one gate each.
;; As i goes 0→1: Rx weight (1-i) decreases, Rz weight i increases.
(define (adiabatic-gates angle)
  (flatten
   (for/list ([i (in-range 0.0 1.0 0.01)])
     (list (RX (* angle (- 1.0 i)))
           (RZ (* angle i))))))

(define a-circuit
  (make-circuit (append (list X H) (adiabatic-gates 30.0))))

(define final (a-circuit q0))

(displayln "Adiabatic sweep (1 qubit, angle=30.0):")
(displayln (format "  P(|0>): ~a" (state-probability final 0)))
(displayln (format "  P(|1>): ~a" (state-probability final 1)))

(define c (counts final #:shots 1024 #:seed 1))
(displayln "Measurement distribution:")
(for ([(k v) (in-hash c)])
  (displayln (format "  ~a : ~a" k v)))
