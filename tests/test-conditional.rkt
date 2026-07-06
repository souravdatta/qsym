#lang racket/base

;; End-to-end test: quantum teleportation.
;;
;; Alice teleports qubit 0 to Bob's qubit 2 using a shared Bell pair.
;; Correctness criterion: for any input payload |ψ⟩, after teleportation
;; qubit-probability(final-state, 2, 1) == qubit-probability(payload, 0, 1).

(require rackunit
         racket/math
         "../private/state.rkt"
         "../private/gates.rkt"
         "../private/circuit.rkt"
         "../private/simulator.rkt"
         "../private/measurement.rkt")

(define tol 1e-6)

(define (approx? a b) (< (abs (- a b)) tol))

;; Teleportation circuit (3 qubits, 2 classical bits):
;;   q0 = payload  q1 = Alice  q2 = Bob
;;
;;   (list I H I)     - Bell pair: H on q1
;;   (at CX 1 2)      - Bell pair: CX ctrl=q1, tgt=q2
;;   (at CX 0 1)      - Alice entangles payload with her qubit
;;   (list H I I)     - H on payload qubit
;;   (measure 0 1)    - Alice measures q0->clbit0, q1->clbit1
;;   (when-bit 1 1 …) - Bob: X if clbit1=1
;;   (when-bit 0 1 …) - Bob: Z if clbit0=1

(define teleport
  (make-circuit
   (list (list ID H ID)
         (at CX 1 2)
         (at CX 0 1)
         (list H ID ID)
         (measure 0 1)
         (when-bit 1 1 (at X 2))
         (when-bit 0 1 (at Z 2)))
   #:clbits 2))

(define (teleport-check payload)
  (define expected-p1 (qubit-probability payload 0 1))
  (define initial (t* payload (qubits 2)))
  ; Average Bob's P(|1⟩) over many shots — each shot has a random classical
  ; outcome but always teleports the state correctly.
  (define rng (make-pseudo-random-generator))
  (parameterize ([current-pseudo-random-generator rng]) (random-seed 42))
  (define shots 500)
  (define total
    (for/fold ([s 0.0]) ([_ (in-range shots)])
      (define-values (st _) (run-shot teleport initial #:rng rng))
      (+ s (qubit-probability st 2 1))))
  (/ total shots))

(test-case "teleportation: |0⟩ payload — Bob gets P(|1⟩)=0"
  (define p (teleport-check q0))
  (check-true (approx? p 0.0)))

(test-case "teleportation: |1⟩ payload — Bob gets P(|1⟩)=1"
  (define payload (gX q0))
  (define p (teleport-check payload))
  (check-true (approx? p 1.0)))

(test-case "teleportation: |+⟩ payload — Bob gets P(|1⟩)=0.5"
  (define payload (gH q0))
  (define p (teleport-check payload))
  (check-true (approx? p 0.5)))

(test-case "teleportation: Rx(π/3) payload — Bob gets P(|1⟩)=sin²(π/6)=0.25"
  (define payload (gRx (/ pi 3) q0))
  (define expected (qubit-probability payload 0 1))  ; sin²(π/6) = 0.25
  (define p (teleport-check payload))
  ; Statistical test: 500 shots, allow 5% tolerance
  (check-true (< (abs (- p expected)) 0.05)))

(test-case "teleportation: Ry(π/4) payload — probability correct"
  (define payload (gRy (/ pi 4) q0))
  (define expected (qubit-probability payload 0 1))
  (define p (teleport-check payload))
  (check-true (< (abs (- p expected)) 0.05)))

;; Per-shot correctness: each individual shot's final state has exactly the
;; right marginal probability on qubit 2 (not just on average).
(test-case "teleportation: per-shot state has correct qubit-2 probability"
  (define payload (gRx (/ pi 3) q0))
  (define expected (qubit-probability payload 0 1))
  (define initial (t* payload (qubits 2)))
  (define rng (make-pseudo-random-generator))
  (parameterize ([current-pseudo-random-generator rng]) (random-seed 7))
  (for ([_ (in-range 30)])
    (define-values (st _) (run-shot teleport initial #:rng rng))
    (check-true (approx? (qubit-probability st 2 1) expected))))
