#lang racket/base

(require rackunit
         math/matrix
         racket/math
         "../private/linalg.rkt"
         "../private/state.rkt"
         "../private/gates.rkt"
         "../private/circuit.rkt"
         "../private/simulator.rkt")

(define (state≈ s1 s2) (state-~= s1 s2))

;; Helper: apply circuit->matrix oracle to a state.
(define (matrix-sim circ state)
  (define n    (circuit-num-qubits circ))
  (define N    (expt 2 n))
  (define mat  (circuit->matrix circ))
  (define amps (quantum-state-amplitudes state))
  (define col  (build-matrix N 1 (λ (i _) (vector-ref amps i))))
  (define out  (matrix* mat col))
  (quantum-state n (vector->immutable-vector
                    (for/vector ([i (in-range N)])
                      (matrix-ref out i 0)))))

;; ---- 1-qubit kernel ---------------------------------------------------------

(test-case "apply-gate-1q: H on qubit 0 of |0⟩"
  (define result (apply-gate-1q (gate-matrix H) 0 (zero-state 1)))
  (define expected (quantum-state 1 (vector->immutable-vector
                                     (vector (/ 1.0 (sqrt 2.0))
                                             (/ 1.0 (sqrt 2.0))))))
  (check-true (state≈ result expected)))

(test-case "apply-gate-1q: H then H = identity on |0⟩"
  (define s0  (zero-state 1))
  (define s1  (apply-gate-1q (gate-matrix H) 0 s0))
  (define s2  (apply-gate-1q (gate-matrix H) 0 s1))
  (check-true (state≈ s2 s0)))

(test-case "apply-gate-1q: X flips |0⟩ to |1⟩"
  (define result (apply-gate-1q (gate-matrix X) 0 (zero-state 1)))
  (check-true (state≈ result (basis-state 1 1))))

(test-case "apply-gate-1q: norm preserved after H"
  (define result (apply-gate-1q (gate-matrix H) 0 (zero-state 2)))
  (check-true (state-normalized? result)))

(test-case "apply-gate-1q: H on qubit 1 of 2-qubit state"
  ;; |00⟩ —H on q1→ |00⟩+|10⟩ / √2  (qubit 1 is the high bit, index 0 vs 2)
  (define result (apply-gate-1q (gate-matrix H) 1 (zero-state 2)))
  (define sqrt2-inv (/ 1.0 (sqrt 2.0)))
  (define expected (quantum-state 2 (vector->immutable-vector
                                     (vector sqrt2-inv 0.0 sqrt2-inv 0.0))))
  (check-true (state≈ result expected)))

;; ---- 2-qubit kernel ---------------------------------------------------------

(test-case "apply-gate-2q: CX(0,1) on |00⟩ leaves state unchanged"
  (define result (apply-gate-2q (gate-matrix CX) 0 1 (zero-state 2)))
  (check-true (state≈ result (zero-state 2))))

(test-case "apply-gate-2q: CX(0,1) on |10⟩ flips to |11⟩"
  ;; |10⟩ = q0=1,q1=0 = basis index 1
  (define result (apply-gate-2q (gate-matrix CX) 0 1 (basis-state 2 1)))
  (check-true (state≈ result (basis-state 2 3))))

(test-case "apply-gate-2q: SWAP(0,1) on |10⟩ gives |01⟩"
  ;; |10⟩ = index 1; |01⟩ = q0=0,q1=1 = index 2
  (define result (apply-gate-2q (gate-matrix SWAP) 0 1 (basis-state 2 1)))
  (check-true (state≈ result (basis-state 2 2))))

(test-case "apply-gate-2q: norm preserved"
  (define s (quantum-state 2 (vector->immutable-vector
                               (vector 0.5+0.5i 0.5 0.0 0.0+0.5i))))
  (define result (apply-gate-2q (gate-matrix CX) 0 1 s))
  (check-true (state-normalized? result)))

;; ---- Bell state via run-state -----------------------------------------------

(test-case "Bell state amplitudes"
  ;; H on q0 then CX(0,1) on |00⟩ -> (|00⟩+|11⟩)/√2
  (define bell-circ
    (make-circuit (list (list H ID)
                        (at CX 0 1))
                  #:qubits 2))
  (define result (run-state bell-circ))
  (define sqrt2-inv (/ 1.0 (sqrt 2.0)))
  ;; index 0 = |q1=0,q0=0⟩, index 3 = |q1=1,q0=1⟩
  (check-true (< (magnitude (- (vector-ref (quantum-state-amplitudes result) 0)
                               sqrt2-inv))
                 1e-9))
  (check-true (< (magnitude (vector-ref (quantum-state-amplitudes result) 1)) 1e-9))
  (check-true (< (magnitude (vector-ref (quantum-state-amplitudes result) 2)) 1e-9))
  (check-true (< (magnitude (- (vector-ref (quantum-state-amplitudes result) 3)
                               sqrt2-inv))
                 1e-9)))

(test-case "Bell state is normalized"
  (define bell-circ
    (make-circuit (list (list H ID) (at CX 0 1)) #:qubits 2))
  (check-true (state-normalized? (run-state bell-circ))))

;; ---- run-state basic --------------------------------------------------------

(test-case "run-state: bare X on |0⟩"
  (define circ (make-circuit (list X) #:qubits 1))
  (check-true (state≈ (run-state circ) (basis-state 1 1))))

(test-case "run-state: default initial state is |0…0⟩"
  (define circ (make-circuit (list (list H ID)) #:qubits 2))
  (define r1 (run-state circ))
  (define r2 (run-state circ (zero-state 2)))
  (check-true (state≈ r1 r2)))

(test-case "run-state: errors on circuit with measure"
  (define circ (make-circuit (list (measure 0)) #:qubits 1 #:clbits 1))
  (check-exn exn:fail? (λ () (run-state circ))))

(test-case "run-state: GHZ state"
  ;; H q0, CX(0,1), CX(1,2) -> (|000⟩+|111⟩)/√2
  (define ghz (make-circuit (list (list H ID ID)
                                  (at CX 0 1)
                                  (at CX 1 2))
                             #:qubits 3))
  (define result (run-state ghz))
  (define sqrt2-inv (/ 1.0 (sqrt 2.0)))
  (define amps (quantum-state-amplitudes result))
  (check-true (< (magnitude (- (vector-ref amps 0) sqrt2-inv)) 1e-9))
  (check-true (< (magnitude (- (vector-ref amps 7) sqrt2-inv)) 1e-9))
  ;; all other amplitudes are 0
  (check-true (for/and ([i '(1 2 3 4 5 6)])
                (< (magnitude (vector-ref amps i)) 1e-9))))

;; ---- gate-then-inverse = identity ------------------------------------------

(test-case "circuit then circuit-inverse = identity state"
  (define circ (make-circuit (list (list H ID)
                                   (at CX 0 1)
                                   (list S T))
                              #:qubits 2))
  (define circ-inv (circuit-inverse circ))
  (define full (circuit-append circ circ-inv))
  (define s0 (zero-state 2))
  (check-true (state≈ (run-state full s0) s0)))

(test-case "gate-inverse round-trip on arbitrary state"
  (define s (quantum-state 2 (vector->immutable-vector
                               (vector 0.5 0.5 0.5 0.5))))
  (define circ     (make-circuit (list (at CX 0 1) (list H Z)) #:qubits 2))
  (define circ-inv (circuit-inverse circ))
  (check-true (state≈ (run-state circ-inv (run-state circ s)) s)))

;; ---- QFT matches fourier-matrix ---------------------------------------------

;; For n qubits, run-state on the QFT circuit applied to each basis state
;; should equal the corresponding column of the Fourier matrix.
(define (qft-matches-fourier? n)
  (define N    (expt 2 n))
  (define F    (fourier-matrix N))
  (define circ (qft n))
  (for/and ([k (in-range N)])
    (define result (run-state circ (basis-state n k)))
    (define expected-amps
      (for/vector ([r (in-range N)]) (matrix-ref F r k)))
    (state≈ result
            (quantum-state n (vector->immutable-vector expected-amps)))))

(test-case "QFT on 2 qubits matches fourier-matrix"
  (check-true (qft-matches-fourier? 2)))

(test-case "QFT on 3 qubits matches fourier-matrix"
  (check-true (qft-matches-fourier? 3)))

(test-case "QFT on 4 qubits matches fourier-matrix"
  (check-true (qft-matches-fourier? 4)))

;; ---- cross-validation: run-state vs circuit->matrix oracle -----------------

;; For a seeded pseudo-random generator — scoped to this test section so we
;; don't mutate the global seed in other tests.
(define (cross-check! circ initial label)
  (define fast   (run-state circ initial))
  (define oracle (matrix-sim circ initial))
  (check-true (state≈ fast oracle) label))

;; Fixed-structure multi-gate circuits
(test-case "cross-validate: H S T on 1 qubit"
  (cross-check! (make-circuit (list H S T H) #:qubits 1) (zero-state 1) "HST 1q"))

(test-case "cross-validate: H CX S CX on 2 qubits"
  (define circ (make-circuit (list (list H ID)
                                   (at CX 0 1)
                                   (list S T)
                                   (at CX 1 0))
                             #:qubits 2))
  (cross-check! circ (zero-state 2) "H CX S CX"))

(test-case "cross-validate: GHZ + local rotations on 3 qubits"
  (define circ (make-circuit (list (list H ID ID)
                                   (at CX 0 1)
                                   (at CX 1 2)
                                   (list S T Sdg)
                                   (at CX 0 2))
                             #:qubits 3))
  (cross-check! circ (zero-state 3) "GHZ extended 3q"))

(test-case "cross-validate: Y CZ SWAP on 3 qubits"
  (define circ (make-circuit (list (list Y H X)
                                   (at CZ 0 2)
                                   (at SWAP 1 2)
                                   (list Z S T)
                                   (at CX 0 1))
                             #:qubits 3))
  (cross-check! circ (basis-state 3 5) "Y CZ SWAP 3q"))

(test-case "cross-validate: CCX (Toffoli) on 3 qubits"
  ;; Prepare |110⟩ = q0=0, q1=1, q2=1 = index 6; CCX should flip q2=qubit with
  ;; Wait: CCX convention in gates.rkt: (at CCX q0 q1 q2) means control0=q0, control1=q1, target=q2.
  ;; Flip q2 when q0=1 AND q1=1. So let's put controls on qubits 0 and 1.
  ;; |q0=1,q1=1,q2=0⟩ = index 3, CCX flips q2 -> index 7.
  (define circ (make-circuit (list (at CCX 0 1 2)) #:qubits 3))
  (define result (run-state circ (basis-state 3 3)))
  (cross-check! circ (basis-state 3 3) "Toffoli |011⟩"))

(test-case "cross-validate: non-trivial 4-qubit circuit"
  (define circ (make-circuit (list (list H H H H)
                                   (at CX 0 1)
                                   (at CX 2 3)
                                   (at CX 1 2)
                                   (list S T S T)
                                   (at CX 0 3)
                                   (list H H H H))
                             #:qubits 4))
  (cross-check! circ (zero-state 4) "4-qubit mixed circuit"))

;; Randomized cross-validation: 20 circuits with seeded RNG
(define POOL-1Q (vector H X Y Z S T Sdg))

(define (make-test-rng)
  ;; Return a fresh seeded generator without touching the global seed.
  (define rng (make-pseudo-random-generator))
  (parameterize ([current-pseudo-random-generator rng])
    (random-seed 20250706))
  rng)

(define (rand-1q-gate rng)
  (vector-ref POOL-1Q (random (vector-length POOL-1Q) rng)))

(define (rand-layer n rng)
  ;; 1 in 3 chance of a 2-qubit gate (when n >= 2), else positional 1q layer.
  (if (and (>= n 2) (= (random 3 rng) 0))
      (let loop ()
        (define ctrl (random n rng))
        (define tgt  (random n rng))
        (if (= ctrl tgt) (loop) (at CX ctrl tgt)))
      (for/list ([_ (in-range n)]) (rand-1q-gate rng))))

(define (rand-circuit n depth rng)
  (make-circuit (for/list ([_ (in-range depth)]) (rand-layer n rng))
                #:qubits n))

(test-case "cross-validate: 20 randomized small circuits"
  (define rng (make-test-rng))
  (for ([trial (in-range 20)])
    (define n     (+ 2 (random 4 rng)))    ; 2..5 qubits
    (define depth (+ 5 (random 16 rng)))   ; 5..20 layers
    (define circ  (rand-circuit n depth rng))
    (define init  (zero-state n))
    (define label (format "trial ~a: ~a qubits depth ~a" trial n depth))
    (cross-check! circ init label)))
