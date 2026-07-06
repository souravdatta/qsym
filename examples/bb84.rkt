#lang racket

;; BB84 quantum key distribution protocol.
;; Alice sends qubits in one of four states {|0⟩,|1⟩,|+⟩,|-⟩}.
;; Bob measures in a randomly chosen basis (Z or X).
;; They keep only bits where bases match; an eavesdropper introduces errors.

(require qsym)

(define (random-bit rng) (if (< (random rng) 0.5) 0 1))

;; Prepare a single qubit in one of four states based on bit and basis.
;;   basis 0 (Z): bit 0 -> |0⟩, bit 1 -> |1⟩
;;   basis 1 (X): bit 0 -> |+⟩, bit 1 -> |-⟩
(define (alice-prepare bit basis)
  (define state (if (= bit 1) (gX q0) q0))
  (if (= basis 1) (gH state) state))

;; Measure a single qubit in a chosen basis.
;; Returns 0 or 1 as a classical bit.
;; basis 0 (Z): measure directly.
;; basis 1 (X): apply H first, then measure.
(define (bob-measure state basis rng)
  (define measure-state (if (= basis 1) (gH state) state))
  (define circ (make-circuit (list (measure 0)) #:qubits 1 #:clbits 1))
  (define-values (_ cbits) (run-shot circ measure-state #:rng rng))
  (vector-ref cbits 0))

(define n-qubits 200)

(define rng (make-pseudo-random-generator))
(parameterize ([current-pseudo-random-generator rng]) (random-seed 42))

;; Alice generates random bits and bases.
(define alice-bits   (for/list ([_ (in-range n-qubits)]) (random-bit rng)))
(define alice-bases  (for/list ([_ (in-range n-qubits)]) (random-bit rng)))

;; Bob chooses random measurement bases.
(define bob-bases    (for/list ([_ (in-range n-qubits)]) (random-bit rng)))

;; Simulate transmission and measurement.
(define bob-results
  (for/list ([bit alice-bits] [ab alice-bases] [bb bob-bases])
    (define qubit (alice-prepare bit ab))
    (bob-measure qubit bb rng)))

;; Sift: keep only bits where Alice and Bob chose the same basis.
(define sifted
  (for/list ([ab alice-bases] [bb bob-bases]
             [abit alice-bits] [bbit bob-results]
             #:when (= ab bb))
    (cons abit bbit)))

(define n-sifted (length sifted))
(define n-match  (for/sum ([pair sifted] #:when (= (car pair) (cdr pair))) 1))
(define qber     (if (= n-sifted 0) 0 (/ (- n-sifted n-match) n-sifted)))

(displayln (format "BB84 simulation (~a qubits):" n-qubits))
(displayln (format "  Sifted key length : ~a bits" n-sifted))
(displayln (format "  Matching bits     : ~a" n-match))
(displayln (format "  QBER (no Eve)     : ~a%  (should be 0%%)" (* 100.0 qber)))
