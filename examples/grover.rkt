#lang racket

;; Grover's search algorithm (2-qubit case, target |11⟩).
;; For n=2, one Grover iteration amplifies the target to probability 1.
;;
;; Circuit structure:
;;   Initialization : H H            (uniform superposition)
;;   Oracle         : CZ             (phase-flip |11⟩)
;;   Diffusion      : H H, X X, CZ, X X, H H

(require qsym)

(define grover-2q
  (make-circuit
   (list (list H H)  ; superposition
         CZ           ; oracle: marks |11⟩ with phase -1
         (list H H)   ; diffusion: H
         (list X X)   ; diffusion: flip
         CZ           ; diffusion: phase-flip |00⟩ (= |11⟩ after flip, up to global phase)
         (list X X)   ; diffusion: unflip
         (list H H))  ; diffusion: H
   #:qubits 2))

(define result (grover-2q (qubits 2)))

(displayln "Grover 2-qubit (target |11>):")
(displayln (format "P(|11>): ~a  (should be ~a 1.0)" (state-probability result 3) '≈))

(define c (counts result #:shots 1024 #:seed 1))
(displayln "Measurement counts:")
(for ([(k v) (in-hash c)])
  (displayln (format "  ~a : ~a" k v)))
