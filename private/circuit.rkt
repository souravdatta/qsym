#lang racket/base

;; Circuit IR: layer-item structs, circuit struct, builder, composition,
;; inverse, QFT, tensor product of states, and the gate-application kernels.
;;
;; The kernels (apply-gate-kq/1q/2q, apply-item) live here rather than in
;; simulator.rkt so that circuit's prop:procedure can use the O(2^n) fast path
;; without creating a circular module dependency.
;;
;; Layer types accepted by make-circuit:
;;   (list g0 g1 ...)  positional: gi is a 1-qubit gate on qubit i
;;   gate              bare: applied to qubits 0..arity-1
;;   gate-at           gate at explicit qubit indices
;;   measure-at        measurement (Phase 4)
;;   when-bit*         classically-conditioned item (Phase 4)
;;
;; Convention: (at gate q0 q1 ...) -> local qubit 0 = q0, etc.; control first.
;; Endianness: qubit i = bit i of state index (little-endian, Qiskit-compatible).

(require math/matrix
         racket/math
         racket/list
         racket/vector
         "linalg.rkt"
         "gates.rkt"
         "state.rkt")

(provide
 ;; layer-item structs
 (struct-out gate-at)
 (struct-out measure-at)
 (struct-out when-bit*)
 ;; circuit struct
 (struct-out circuit)
 ;; layer-item constructors
 at
 measure
 when-bit
 ;; circuit builder & accessors
 make-circuit
 circuit-layers
 ;; circuit combinators
 circuit-append
 circuit-repeat
 circuit-inverse
 circuit->gate
 circuit->matrix
 ;; QFT
 qft
 inverse-qft
 ;; tensor product of states
 t*
 ;; gate-application kernels (used by simulator.rkt and measurement.rkt)
 apply-gate-kq
 apply-gate-1q
 apply-gate-2q
 apply-item)

;; ---- layer-item structs ----------------------------------------------------

(struct gate-at    (gate qubits)      #:transparent)
(struct measure-at (qubits clbits)    #:transparent)
(struct when-bit*  (clbit value item) #:transparent)

;; ---- circuit struct with prop:procedure ------------------------------------

(struct circuit (num-qubits num-clbits layers)
  #:transparent
  #:property prop:procedure
  (λ (self state) (circuit-run-state self state)))

;; ---- layer-item constructors -----------------------------------------------

(define (at g . qubit-indices)
  (unless (gate? g)
    (error 'at "expected a gate, got ~a" g))
  (unless (= (length qubit-indices) (gate-arity g))
    (error 'at "gate ~a has arity ~a but ~a qubit indices given"
           (gate-name g) (gate-arity g) (length qubit-indices)))
  (gate-at g qubit-indices))

;; (measure q ...) or (measure [q c] ...) -> measure-at.
;; Plain integer arg: qubit index, classical bit index = same.
;; List arg [q c]: qubit q -> classical bit c.
(define (measure . args)
  (define-values (qs cs)
    (for/fold ([qs '()] [cs '()])
              ([a args])
      (cond
        [(list? a)
         (unless (= (length a) 2)
           (error 'measure "list argument must be [qubit clbit], got ~a" a))
         (values (append qs (list (first a)))
                 (append cs (list (second a))))]
        [(exact-nonneg-integer? a)
         (values (append qs (list a)) (append cs (list a)))]
        [else
         (error 'measure "expected integer or [q c] pair, got ~a" a)])))
  (measure-at qs cs))

(define (when-bit clbit value item)
  (when-bit* clbit value item))

;; ---- validation helpers ----------------------------------------------------

(define (exact-nonneg-integer? x)
  (and (exact-integer? x) (>= x 0)))

(define (check-indices! who indices n label)
  (for ([idx indices])
    (unless (and (exact-nonneg-integer? idx) (< idx n))
      (error who "~a index ~a out of range [0, ~a)" label idx n)))
  (when (not (= (length indices) (length (remove-duplicates indices))))
    (error who "duplicate ~a indices: ~a" label indices)))

(define (layer-min-qubits item)
  (cond
    [(list? item)       (length item)]
    [(gate? item)       (gate-arity item)]
    [(gate-at? item)    (add1 (apply max (gate-at-qubits item)))]
    [(measure-at? item) (add1 (apply max (measure-at-qubits item)))]
    [(when-bit*? item)  (layer-min-qubits (when-bit*-item item))]
    [else (error 'make-circuit "unrecognized layer item: ~a" item)]))

(define (layer-min-clbits item)
  (cond
    [(measure-at? item)
     (add1 (apply max (measure-at-clbits item)))]
    [(when-bit*? item)
     (max (add1 (when-bit*-clbit item))
          (layer-min-clbits (when-bit*-item item)))]
    [else 0]))

(define (validate-item! item n-qubits n-clbits)
  (cond
    [(list? item)
     (unless (= (length item) n-qubits)
       (error 'make-circuit
              "positional layer length ~a != circuit qubit count ~a"
              (length item) n-qubits))
     (for ([g item])
       (unless (and (gate? g) (= (gate-arity g) 1))
         (error 'make-circuit
                "positional layer entry must be a 1-qubit gate, got ~a" g)))]
    [(gate? item)
     (unless (<= (gate-arity item) n-qubits)
       (error 'make-circuit
              "bare gate ~a arity ~a exceeds circuit qubit count ~a"
              (gate-name item) (gate-arity item) n-qubits))]
    [(gate-at? item)
     (check-indices! 'make-circuit (gate-at-qubits item) n-qubits "qubit")]
    [(measure-at? item)
     (check-indices! 'make-circuit (measure-at-qubits item) n-qubits "qubit")
     (check-indices! 'make-circuit (measure-at-clbits item) n-clbits "clbit")]
    [(when-bit*? item)
     (check-indices! 'make-circuit (list (when-bit*-clbit item)) n-clbits "clbit")
     (validate-item! (when-bit*-item item) n-qubits n-clbits)]))

;; ---- make-circuit ----------------------------------------------------------

(define (make-circuit layers #:qubits [n #f] #:clbits [m 0])
  (define n-qubits
    (or n (if (null? layers)
              (error 'make-circuit
                     "cannot infer qubit count from empty layers; pass #:qubits")
              (apply max (map layer-min-qubits layers)))))
  (define n-clbits
    (max m (if (null? layers) 0
               (apply max 0 (map layer-min-clbits layers)))))
  (when (= n-qubits 0)
    (error 'make-circuit "qubit count is 0; pass #:qubits with a positive value"))
  (for ([item layers])
    (validate-item! item n-qubits n-clbits))
  (circuit n-qubits n-clbits layers))

;; ---- gate-application kernels ----------------------------------------------
;;
;; O(2^n) per gate: partition basis indices into groups by their "base" (all
;; target bits cleared); apply the gate matrix to each group's sub-vector.
;; All mutation is local: a fresh mutable vector is filled and frozen.

(define (apply-gate-kq mat qs state)
  (define n     (quantum-state-num-qubits state))
  (define N     (expt 2 n))
  (define k     (length qs))
  (define K     (expt 2 k))
  (define amps  (quantum-state-amplitudes state))
  (define steps (list->vector (map (lambda (q) (expt 2 q)) qs)))
  (define mask  (for/fold ([m 0]) ([s (in-vector steps)]) (bitwise-ior m s)))
  (define out   (vector-copy amps))
  (for ([base (in-range N)]
        #:when (= (bitwise-and base mask) 0))
    (define idx-vec
      (for/vector ([s (in-range K)])
        (for/fold ([idx base])
                  ([step (in-vector steps)] [pos (in-naturals)])
          (+ idx (* step (bitwise-and (arithmetic-shift s (- pos)) 1))))))
    (define old-vals
      (for/vector ([c (in-range K)])
        (vector-ref amps (vector-ref idx-vec c))))
    (for ([r (in-range K)])
      (define new-val
        (for/fold ([acc 0+0i])
                  ([c (in-range K)])
          (+ acc (* (matrix-ref mat r c) (vector-ref old-vals c)))))
      (vector-set! out (vector-ref idx-vec r) new-val)))
  (quantum-state n (vector->immutable-vector out)))

(define (apply-gate-1q mat t state)
  (apply-gate-kq mat (list t) state))

(define (apply-gate-2q mat t0 t1 state)
  (apply-gate-kq mat (list t0 t1) state))

;; apply-item: dispatch one measurement-free layer item to the appropriate kernel.
(define (apply-item item state)
  (cond
    [(list? item)
     (for/fold ([st state])
               ([g item] [i (in-naturals)])
       (if (eq? (gate-name g) 'id)
           st
           (apply-gate-1q (gate-matrix g) i st)))]
    [(gate? item)
     (apply-gate-kq (gate-matrix item)
                    (for/list ([i (in-range (gate-arity item))]) i)
                    state)]
    [(gate-at? item)
     (apply-gate-kq (gate-matrix (gate-at-gate item))
                    (gate-at-qubits item)
                    state)]
    [else
     (error 'apply-item "unrecognized layer item: ~a" item)]))

;; ---- circuit->matrix -------------------------------------------------------
;;
;; Full 2^n × 2^n unitary matrix for a measurement-free circuit.
;; Kept as a test oracle (cross-validates the index-arithmetic kernels).

(define (circuit->matrix circ)
  (define n (circuit-num-qubits circ))
  (define N (expt 2 n))
  (for/fold ([acc (identity-matrix N)])
            ([item (circuit-layers circ)])
    (matrix* (layer->matrix item n) acc)))

(define (layer->matrix item n)
  (define N (expt 2 n))
  (cond
    [(list? item)
     (for/fold ([m (matrix [[1]])])
               ([g item])
       (tensor-product (gate-matrix g) m))]
    [(gate? item)
     (let ([k (gate-arity item)])
       (for/fold ([m (gate-matrix item)])
                 ([_ (in-range (- n k))])
         (tensor-product (identity-matrix 2) m)))]
    [(gate-at? item)
     (gate-at->matrix item n)]
    [(or (measure-at? item) (when-bit*? item))
     (identity-matrix N)]
    [else
     (error 'circuit->matrix "unrecognized layer item: ~a" item)]))

(define (gate-at->matrix item n)
  (define g    (gate-at-gate item))
  (define qs   (gate-at-qubits item))
  (define k    (gate-arity g))
  (define N    (expt 2 n))
  (define g-mat (gate-matrix g))
  (define result (make-vector (* N N) 0))
  (for ([col (in-range N)])
    (define sub-col
      (for/fold ([s 0])
                ([qi qs] [pos (in-naturals)])
        (+ s (* (bitwise-and (arithmetic-shift col (- qi)) 1)
                (expt 2 pos)))))
    (for ([sub-row (in-range (expt 2 k))])
      (define entry (matrix-ref g-mat sub-row sub-col))
      (unless (= entry 0)
        (define full-row
          (for/fold ([r col])
                    ([qi qs] [pos (in-naturals)])
            (define bit-val (bitwise-and (arithmetic-shift sub-row (- pos)) 1))
            (define cleared (bitwise-and r (bitwise-not (expt 2 qi))))
            (+ cleared (* bit-val (expt 2 qi)))))
        (vector-set! result (+ (* full-row N) col) entry))))
  (list*->matrix
   (for/list ([r (in-range N)])
     (for/list ([c (in-range N)])
       (vector-ref result (+ (* r N) c))))))

;; ---- circuit application (prop:procedure target) ---------------------------
;;
;; Uses the index-arithmetic kernels for O(2^n) per gate.
;; Errors on circuits with measurement; use run-shot for those.

(define (circuit-run-state circ state)
  (unless (= (circuit-num-qubits circ) (quantum-state-num-qubits state))
    (error 'circuit "circuit has ~a qubits but state has ~a"
           (circuit-num-qubits circ) (quantum-state-num-qubits state)))
  (when (ormap (λ (item) (or (measure-at? item) (when-bit*? item)))
               (circuit-layers circ))
    (error 'circuit "circuit contains measurement; use run-shot"))
  (for/fold ([st state])
            ([item (circuit-layers circ)])
    (apply-item item st)))

;; ---- circuit combinators ---------------------------------------------------

(define (circuit-append c1 c2)
  (unless (= (circuit-num-qubits c1) (circuit-num-qubits c2))
    (error 'circuit-append "qubit counts differ: ~a vs ~a"
           (circuit-num-qubits c1) (circuit-num-qubits c2)))
  (circuit (circuit-num-qubits c1)
           (max (circuit-num-clbits c1) (circuit-num-clbits c2))
           (append (circuit-layers c1) (circuit-layers c2))))

(define (circuit-repeat circ n)
  (circuit (circuit-num-qubits circ)
           (circuit-num-clbits circ)
           (apply append (make-list n (circuit-layers circ)))))

(define (circuit-inverse circ)
  (define (invert-item item)
    (cond
      [(list? item)    (map gate-inverse item)]
      [(gate? item)    (gate-inverse item)]
      [(gate-at? item) (gate-at (gate-inverse (gate-at-gate item))
                                (gate-at-qubits item))]
      [else (error 'circuit-inverse "cannot invert measurement layer")]))
  (circuit (circuit-num-qubits circ)
           (circuit-num-clbits circ)
           (map invert-item (reverse (circuit-layers circ)))))

(define (circuit->gate name circ)
  (when (ormap (λ (item) (or (measure-at? item) (when-bit*? item)))
               (circuit-layers circ))
    (error 'circuit->gate "circuit contains measurement"))
  (define mat (circuit->matrix circ))
  (unless (matrix-unitary? mat)
    (error 'circuit->gate "circuit matrix is not unitary"))
  (gate name (circuit-num-qubits circ) mat '()))

;; ---- QFT -------------------------------------------------------------------
;;
;; QFT on n qubits built from H and CP gates, little-endian convention.
;; For q = n-1 downto 0: H on q, then CP(π/2^j) with ctrl=(q-j), target=q.
;; Followed by SWAP reversals to match Qiskit's output qubit order.

(define (qft n)
  (define rotation-layers
    (apply append
           (for/list ([q (in-range (- n 1) -1 -1)])
             (cons (at H q)
                   (for/list ([j (in-range 1 (add1 q))])
                     (at (CP (/ pi (expt 2.0 j))) (- q j) q))))))
  (define swap-layers
    (for/list ([i (in-range (quotient n 2))])
      (at SWAP i (- n 1 i))))
  (make-circuit (append rotation-layers swap-layers) #:qubits n))

(define (inverse-qft n)
  (circuit-inverse (qft n)))

;; ---- tensor product of quantum states -------------------------------------
;;
;; (t* s1 s2 ...): s1's qubits become the lower-index qubits.
;; Index: k1 + k2*2^n1 so s1 occupies bits 0..n1-1, s2 occupies bits n1..n1+n2-1.

(define (t* . states)
  (define (tensor-two s1 s2)
    (define n1 (quantum-state-num-qubits s1))
    (define n2 (quantum-state-num-qubits s2))
    (define a1 (quantum-state-amplitudes s1))
    (define a2 (quantum-state-amplitudes s2))
    (define size1 (expt 2 n1))
    (define new-amps
      (for*/vector ([k2 (in-range (expt 2 n2))]
                    [k1 (in-range size1)])
        (* (vector-ref a1 k1) (vector-ref a2 k2))))
    (quantum-state (+ n1 n2) (vector->immutable-vector new-amps)))
  (cond
    [(null? states)       (error 't* "no states given")]
    [(null? (cdr states)) (car states)]
    [else                 (tensor-two (car states) (apply t* (cdr states)))]))
