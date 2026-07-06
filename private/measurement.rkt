#lang racket/base

;; Measurement, state collapse, sampling, and multi-shot execution.
;;
;; Fixes the legacy integer-roll defect: all sampling uses (random rng), a
;; real in [0,1), against cumulative probabilities — no 1% quantization.
;;
;; Immutability: the classical register is a local mutable vector that is
;; frozen (vector->immutable-vector) before being returned to callers.

(require racket/math
         "linalg.rkt"
         "state.rkt"
         "gates.rkt"
         "circuit.rkt")

(provide
 marginal-distribution
 collapse-state
 run-shot
 counts
 run-shots
 probabilities)

;; ---- helpers ---------------------------------------------------------------

;; make-seeded-rng: create an isolated pseudo-random-generator with optional seed.
(define (make-seeded-rng seed)
  (if seed
      (let ([rng (make-pseudo-random-generator)])
        (parameterize ([current-pseudo-random-generator rng])
          (random-seed seed))
        rng)
      (current-pseudo-random-generator)))

;; sample-outcome: given a vector of probabilities, sample an index using rng.
;; Scans cumulative sums; the last index is returned if floats don't sum to 1.
(define (sample-outcome probs rng)
  (define r (random rng))
  (define K (vector-length probs))
  (let loop ([i 0] [cumsum 0.0])
    (if (>= i K)
        (- K 1)
        (let ([next (+ cumsum (vector-ref probs i))])
          (if (< r next)
              i
              (loop (+ i 1) next))))))

;; ---- marginal-distribution -------------------------------------------------

;; Compute the joint probability distribution over a list of qubit indices qs.
;; Returns a vector of length 2^(length qs): entry s is P(bit i of s = qs[i]'s value).
;; Qubit qs[0] = bit 0 of s, qs[1] = bit 1 of s, etc.
(define (marginal-distribution state qs)
  (define n      (quantum-state-num-qubits state))
  (define N      (expt 2 n))
  (define k      (length qs))
  (define K      (expt 2 k))
  (define amps   (quantum-state-amplitudes state))
  (define qs-vec (list->vector qs))
  (define probs  (make-vector K 0.0))
  (for ([idx (in-range N)])
    (define sub-idx
      (for/fold ([s 0]) ([pos (in-range k)])
        (define qi (vector-ref qs-vec pos))
        (+ s (* (bitwise-and (arithmetic-shift idx (- qi)) 1)
                (expt 2 pos)))))
    (define a (vector-ref amps idx))
    (define p (+ (* (real-part a) (real-part a)) (* (imag-part a) (imag-part a))))
    (vector-set! probs sub-idx (+ (vector-ref probs sub-idx) p)))
  probs)

;; ---- collapse-state --------------------------------------------------------

;; Zero out amplitudes inconsistent with qubit-outcomes (list of (qubit . value)
;; pairs), then renormalize.  The collapsed state is the post-measurement state.
(define (collapse-state state qubit-outcomes)
  (define n    (quantum-state-num-qubits state))
  (define N    (expt 2 n))
  (define amps (quantum-state-amplitudes state))
  (define new-amps (make-vector N 0+0i))
  (define norm-sq
    (for/fold ([s 0.0])
              ([idx (in-range N)])
      (define consistent?
        (for/and ([qo qubit-outcomes])
          (= (bitwise-and (arithmetic-shift idx (- (car qo))) 1) (cdr qo))))
      (cond
        [consistent?
         (define a (vector-ref amps idx))
         (vector-set! new-amps idx a)
         (+ s (* (real-part a) (real-part a)) (* (imag-part a) (imag-part a)))]
        [else s])))
  (define norm (sqrt norm-sq))
  (quantum-state n
    (vector->immutable-vector
     (for/vector #:length N ([a (in-vector new-amps)])
       (/ a norm)))))

;; ---- run-shot --------------------------------------------------------------

;; Execute one shot of a circuit with full mid-circuit measurement semantics.
;; Threads (quantum-state, classical-bits) through the layer list:
;;   gate layers   -> apply kernel
;;   measure-at    -> sample outcome, collapse state, record bits
;;   when-bit*     -> apply inner item iff classical bit matches
;; Returns (values final-state classical-bits) where classical-bits is an
;; immutable vector of length circuit-num-clbits.
(define (run-shot circ [initial-state #f] #:rng [rng (current-pseudo-random-generator)])
  (define n      (circuit-num-qubits circ))
  (define m      (circuit-num-clbits circ))
  (define state0 (or initial-state (zero-state n)))
  (unless (= n (quantum-state-num-qubits state0))
    (error 'run-shot "circuit has ~a qubits but state has ~a"
           n (quantum-state-num-qubits state0)))
  (define cbits (make-vector m 0))
  (define final-state
    (for/fold ([st state0])
              ([item (circuit-layers circ)])
      (apply-shot-item! item st cbits rng)))
  (values final-state (vector->immutable-vector cbits)))

;; apply-shot-item!: execute one layer item, mutating cbits for measurement results.
(define (apply-shot-item! item state cbits rng)
  (cond
    [(or (list? item) (gate? item) (gate-at? item))
     (apply-item item state)]
    [(measure-at? item)
     (define qs      (measure-at-qubits item))
     (define cs      (measure-at-clbits item))
     (define probs   (marginal-distribution state qs))
     (define outcome (sample-outcome probs rng))
     (define qubit-outcomes
       (for/list ([qi qs] [pos (in-naturals)])
         (cons qi (bitwise-and (arithmetic-shift outcome (- pos)) 1))))
     (for ([ci cs] [pos (in-naturals)])
       (vector-set! cbits ci (bitwise-and (arithmetic-shift outcome (- pos)) 1)))
     (collapse-state state qubit-outcomes)]
    [(when-bit*? item)
     (if (= (vector-ref cbits (when-bit*-clbit item)) (when-bit*-value item))
         (apply-shot-item! (when-bit*-item item) state cbits rng)
         state)]
    [else (error 'run-shot "unrecognized layer item: ~a" item)]))

;; ---- counts ----------------------------------------------------------------

;; Sample shots from a quantum state (no circuit, no collapse).
;; Returns an immutable hash: bit-string -> count.
;; Bit strings are MSB-first (qubit 0 rightmost, Qiskit convention).
;; Reproducible when #:seed is given.
(define (counts state #:shots [shots 1024] #:seed [seed #f])
  (define rng   (make-seeded-rng seed))
  (define n     (quantum-state-num-qubits state))
  (define N     (expt 2 n))
  (define amps  (quantum-state-amplitudes state))
  (define probs (for/vector #:length N ([a (in-vector amps)])
                  (+ (* (real-part a) (real-part a)) (* (imag-part a) (imag-part a)))))
  (for/fold ([acc (hash)])
            ([_ (in-range shots)])
    (define k (sample-outcome probs rng))
    (hash-update acc (index->bit-string n k) add1 0)))

;; ---- run-shots -------------------------------------------------------------

;; Run a circuit with measurement #:shots times, tallying the classical register.
;; Returns an immutable hash: bit-string -> count (same shape as counts).
(define (run-shots circ [initial-state #f] #:shots [shots 1024] #:seed [seed #f])
  (define rng    (make-seeded-rng seed))
  (define n      (circuit-num-qubits circ))
  (define m      (circuit-num-clbits circ))
  (define state0 (or initial-state (zero-state n)))
  (for/fold ([acc (hash)])
            ([_ (in-range shots)])
    (define-values (_ cbits) (run-shot circ state0 #:rng rng))
    (define k (for/fold ([s 0]) ([i (in-range m)])
                (+ s (* (vector-ref cbits i) (expt 2 i)))))
    (hash-update acc (index->bit-string m k) add1 0)))

;; ---- probabilities ---------------------------------------------------------

;; Exact probability distribution of a state without sampling.
;; Returns an immutable hash: bit-string -> probability.
;; Only bit-strings with non-zero probability are included.
(define (probabilities state)
  (define n    (quantum-state-num-qubits state))
  (define N    (expt 2 n))
  (define amps (quantum-state-amplitudes state))
  (for/fold ([acc (hash)])
            ([k (in-range N)])
    (define a (vector-ref amps k))
    (define p (+ (* (real-part a) (real-part a)) (* (imag-part a) (imag-part a))))
    (if (> p 0.0)
        (hash-set acc (index->bit-string n k) p)
        acc)))
