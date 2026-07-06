#lang racket

;; Quantum teleportation: Alice sends the state of qubit 0 to Bob's qubit 2
;; using a shared Bell pair (qubits 1,2) and two classical bits.
;;
;;  q0 (payload) ─────●──[H]──[M]══════════╗        (clbit 0)
;;  q1 (Alice)  ──[H]──●──⊕────[M]══╗       ║        (clbit 1)
;;  q2 (Bob)    ────────⊕────────────[X if 1]─[Z if 1] ← payload arrives

(require qsym)

(define teleport
  (make-circuit (list (list ID H ID)
                      (at CX 1 2)
                      (at CX 0 1)
                      (list H ID ID)
                      (measure 0 1)
                      (when-bit 1 1 (at X 2))
                      (when-bit 0 1 (at Z 2)))
                #:clbits 2))

;; Payload: arbitrary single-qubit state on qubit 0.
(define payload (gRx (/ pi 3) q0))

;; Initial state: payload on q0, Bell pair starts as |00⟩ on q1,q2.
(define initial (t* payload (qubits 2)))

;; One shot: the circuit prepares the Bell pair internally (H on q1, CX on q1→q2).
(define-values (final-state cbits) (run-shot teleport initial))

(displayln (format "Alice's classical bits: ~a" (vector->list cbits)))

;; Correctness: qubit 2's marginal probability matches the payload's.
(displayln (format "payload  P(|1>):     ~a" (qubit-probability payload 0 1)))
(displayln (format "Bob q2   P(|1>):     ~a" (qubit-probability final-state 2 1)))

;; Statistics: append a measurement of Bob's qubit to see the teleported distribution.
(define teleport+check
  (circuit-append teleport
                  (make-circuit (list (measure (list 2 0))) #:qubits 3 #:clbits 2)))

(define c (run-shots teleport+check initial #:shots 2048 #:seed 42))
(displayln (format "\nBob's qubit distribution over 2048 shots:"))
(for ([(k v) (in-hash c)])
  (displayln (format "  ~a : ~a" k v)))
;; clbit 0 carries Bob's qubit; expect ~75% '0', ~25% '1' for Rx(π/3).
