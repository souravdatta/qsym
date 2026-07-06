#lang racket

;; Quantum Fourier Transform demo.
;; Demonstrates that QFT on a computational basis state |k⟩ matches
;; the DFT column of the Fourier matrix.

(require qsym
         math/matrix)

(define n 4)
(define N (expt 2 n))

(define qft-circ    (qft n))
(define inv-qft-circ (inverse-qft n))
(define F (fourier-matrix N))

;; QFT|k⟩ should match column k of the Fourier matrix.
(displayln (format "QFT on ~a qubits (~a-dimensional):" n N))
(for ([k (in-range N)])
  (define qft-state (qft-circ (basis-state n k)))
  (define amps (quantum-state-amplitudes qft-state))
  ; Compare to column k of the Fourier matrix.
  (define ok?
    (for/and ([row (in-range N)])
      (< (magnitude (- (vector-ref amps row) (matrix-ref F row k))) 1e-9)))
  (displayln (format "  |~a> matches Fourier column ~a: ~a" k k ok?)))

;; QFT then IQFT = identity.
(displayln "\nQFT ∘ IQFT = identity check:")
(for ([k (in-range N)])
  (define state (basis-state n k))
  (define roundtrip (inv-qft-circ (qft-circ state)))
  (displayln (format "  |~a> roundtrip ok: ~a" k (state-~= state roundtrip))))
