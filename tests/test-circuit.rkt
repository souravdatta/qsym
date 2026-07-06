#lang racket/base

(require rackunit
         math/matrix
         "../private/linalg.rkt"
         "../private/state.rkt"
         "../private/gates.rkt"
         "../private/circuit.rkt")

(define (mat≈ m1 m2) (matrix-~= m1 m2))
(define (state≈ s1 s2) (state-~= s1 s2))

;; ---- struct constructors ---------------------------------------------------

(test-case "gate-at struct"
  (define ga (at CX 0 1))
  (check-true (gate-at? ga))
  (check-equal? (gate-at-qubits ga) '(0 1)))

(test-case "at checks arity"
  (check-exn exn:fail? (λ () (at CX 0)))       ; CX needs 2 qubits
  (check-exn exn:fail? (λ () (at H 0 1))))     ; H needs 1 qubit

(test-case "measure returns measure-at"
  (define m (measure 0 1))
  (check-true (measure-at? m))
  (check-equal? (measure-at-qubits m) '(0 1))
  (check-equal? (measure-at-clbits m) '(0 1)))

(test-case "measure with remapped clbit"
  (define m (measure (list 0 2)))
  (check-equal? (measure-at-qubits m) '(0))
  (check-equal? (measure-at-clbits m) '(2)))

(test-case "when-bit returns when-bit*"
  (define wb (when-bit 1 1 (at X 2)))
  (check-true (when-bit*? wb))
  (check-equal? (when-bit*-clbit wb) 1)
  (check-equal? (when-bit*-value wb) 1))

;; ---- make-circuit validation -----------------------------------------------

(test-case "make-circuit: basic positional layer"
  (define c (make-circuit (list (list H ID)) #:qubits 2))
  (check-equal? (circuit-num-qubits c) 2)
  (check-equal? (circuit-num-clbits c) 0))

(test-case "make-circuit: bare 2-qubit gate"
  (define c (make-circuit (list CX) #:qubits 2))
  (check-equal? (circuit-num-qubits c) 2))

(test-case "make-circuit: gate-at infers qubit count"
  (define c (make-circuit (list (at CX 0 3))))
  (check-equal? (circuit-num-qubits c) 4))

(test-case "make-circuit: measure infers clbit count"
  (define c (make-circuit (list (measure (list 0 2))) #:qubits 3))
  (check-equal? (circuit-num-clbits c) 3))

(test-case "make-circuit: positional layer length mismatch errors"
  (check-exn exn:fail?
             (λ () (make-circuit (list (list H ID)) #:qubits 3))))

(test-case "make-circuit: qubit index out of range errors"
  (check-exn exn:fail?
             (λ () (make-circuit (list (at CX 0 5)) #:qubits 4))))

(test-case "make-circuit: arity mismatch in at errors"
  (check-exn exn:fail?
             (λ () (at H 0 1))))

;; ---- circuit->matrix: known small circuits ---------------------------------

(test-case "circuit->matrix: single H on 1-qubit circuit"
  (define c (make-circuit (list H) #:qubits 1))
  (check-true (mat≈ (circuit->matrix c) (gate-matrix H))))

(test-case "circuit->matrix: H then H = identity"
  (define c (make-circuit (list H H) #:qubits 1))
  (check-true (mat≈ (circuit->matrix c) (identity-matrix 2))))

(test-case "circuit->matrix: positional H I on 2 qubits = H⊗I"
  ;; H on qubit 0, I on qubit 1: full matrix = I⊗H (q1=MSB factor, q0=LSB factor)
  (define c (make-circuit (list (list H ID)) #:qubits 2))
  (define expected (tensor-product (gate-matrix ID) (gate-matrix H)))
  (check-true (mat≈ (circuit->matrix c) expected)))

(test-case "circuit->matrix: bare CX on 2-qubit circuit"
  (define c (make-circuit (list CX) #:qubits 2))
  (check-true (mat≈ (circuit->matrix c) (gate-matrix CX))))

(test-case "circuit->matrix: (at CX 0 1) on 2-qubit circuit = CX matrix"
  (define c (make-circuit (list (at CX 0 1)) #:qubits 2))
  (check-true (mat≈ (circuit->matrix c) (gate-matrix CX))))

;; ---- Bell state via prop:procedure -----------------------------------------

(test-case "Bell state: H then CX gives correct amplitudes"
  ;; Start: |00⟩
  ;; After (list H ID): (|0⟩+|1⟩)/√2 ⊗ |0⟩ = (|00⟩+|10⟩)/√2   [q0=H applied]
  ;; Wait — H on q0, ID on q1: the full state is H|0⟩ ⊗ |0⟩:
  ;; (|0⟩+|1⟩)/√2 ⊗ |0⟩ = (|00⟩+|01⟩)/√2 in MSB-first notation
  ;; but in our index encoding: |q1 q0⟩ -> index = q0 + 2*q1
  ;; H|0⟩⊗|0⟩ = (|0⟩+|1⟩)/√2 ⊗ |0⟩: q0=(0+1)/√2, q1=0
  ;;   -> amp[0] (q0=0,q1=0) = 1/√2
  ;;   -> amp[1] (q0=1,q1=0) = 1/√2
  ;; Then CX (ctrl=q0, tgt=q1): flips q1 when q0=1:
  ;;   amp[0] stays (q0=0, no flip)
  ;;   amp[1] -> goes to index 3 (q0=1,q1=1)
  ;; Final: amp[0]=1/√2, amp[3]=1/√2
  (define bell-circ
    (make-circuit (list (list H ID)
                        (at CX 0 1))
                  #:qubits 2))
  (define result (bell-circ (qubits 2)))
  (define h (/ 1.0 (sqrt 2.0)))
  (check-= (magnitude (vector-ref (quantum-state-amplitudes result) 0)) h 1e-9)
  (check-= (magnitude (vector-ref (quantum-state-amplitudes result) 3)) h 1e-9)
  (check-= (magnitude (vector-ref (quantum-state-amplitudes result) 1)) 0.0 1e-9)
  (check-= (magnitude (vector-ref (quantum-state-amplitudes result) 2)) 0.0 1e-9)
  (check-true (state-normalized? result)))

;; ---- GHZ state -------------------------------------------------------------

(test-case "GHZ state: H on q0 then CNOT q0->q1 then CNOT q0->q2"
  (define ghz-circ
    (make-circuit (list (list H ID ID)
                        (at CX 0 1)
                        (at CX 0 2))
                  #:qubits 3))
  (define result (ghz-circ (qubits 3)))
  (define h (/ 1.0 (sqrt 2.0)))
  ;; Expected: (|000⟩ + |111⟩)/√2 -> amp[0]=h, amp[7]=h, all others 0
  (check-= (magnitude (vector-ref (quantum-state-amplitudes result) 0)) h 1e-9)
  (check-= (magnitude (vector-ref (quantum-state-amplitudes result) 7)) h 1e-9)
  (check-true (state-normalized? result)))

;; ---- circuit combinators ---------------------------------------------------

(test-case "circuit-append: Bell then inverse-Bell = identity"
  (define bell-layers
    (list (list H ID) (at CX 0 1)))
  (define bell (make-circuit bell-layers #:qubits 2))
  (define inv-bell (circuit-inverse bell))
  (define roundtrip (circuit-append bell inv-bell))
  (check-true (mat≈ (circuit->matrix roundtrip) (identity-matrix 4))))

(test-case "circuit-repeat: X repeated twice = identity"
  (define c (circuit-repeat (make-circuit (list X) #:qubits 1) 2))
  (check-true (mat≈ (circuit->matrix c) (identity-matrix 2))))

(test-case "circuit-inverse of single H = H (self-inverse)"
  (define c (circuit-inverse (make-circuit (list H) #:qubits 1)))
  (check-true (mat≈ (circuit->matrix c) (gate-matrix H))))

(test-case "circuit-inverse reverses layer order"
  ;; H then S inverted = S† then H
  (define c (make-circuit (list H S) #:qubits 1))
  (define ci (circuit-inverse c))
  (define expected
    (matrix* (gate-matrix H) (gate-matrix Sdg)))
  (check-true (mat≈ (circuit->matrix ci) expected)))

(test-case "circuit->gate wraps a 2-qubit circuit"
  (define bell-gate
    (circuit->gate 'bell (make-circuit (list (list H ID) (at CX 0 1)) #:qubits 2)))
  (check-equal? (gate-arity bell-gate) 2)
  (check-true (matrix-unitary? (gate-matrix bell-gate))))

;; ---- t* tensor product of states -------------------------------------------

(test-case "t* of two |0⟩ states = |00⟩"
  (define combined (t* q0 q0))
  (check-equal? (quantum-state-num-qubits combined) 2)
  (check-= (magnitude (vector-ref (quantum-state-amplitudes combined) 0)) 1.0 1e-9))

(test-case "t* puts first state in lower qubit positions"
  ;; basis-state 1 0 = |1⟩ (qubit 0 = 1)
  ;; t* (|1⟩) (|0⟩) should give amp[1]=1 (index 1 = q0=1,q1=0)
  (define s1 (basis-state 1 1))   ; |1⟩
  (define s2 (basis-state 1 0))   ; |0⟩
  (define combined (t* s1 s2))
  (check-= (magnitude (vector-ref (quantum-state-amplitudes combined) 1)) 1.0 1e-9))

;; ---- QFT -------------------------------------------------------------------

(test-case "qft 1 = H gate"
  (define q1-circ (qft 1))
  (check-true (mat≈ (circuit->matrix q1-circ) (gate-matrix H))))

(test-case "qft then inverse-qft = identity (n=2)"
  (define roundtrip (circuit-append (qft 2) (inverse-qft 2)))
  (check-true (mat≈ (circuit->matrix roundtrip) (identity-matrix 4))))

(test-case "qft then inverse-qft = identity (n=3)"
  (define roundtrip (circuit-append (qft 3) (inverse-qft 3)))
  (check-true (mat≈ (circuit->matrix roundtrip) (identity-matrix 8))))

(test-case "qft matrix matches fourier-matrix for n=2"
  ;; The QFT circuit should compute the same transformation as fourier-matrix(4).
  (define q2-mat (circuit->matrix (qft 2)))
  (define f4     (fourier-matrix 4))
  (check-true (mat≈ q2-mat f4)))

(test-case "qft matrix matches fourier-matrix for n=3"
  (define q3-mat (circuit->matrix (qft 3)))
  (define f8     (fourier-matrix 8))
  (check-true (mat≈ q3-mat f8)))

(test-case "qft circuit matrix is unitary"
  (for ([n '(1 2 3 4)])
    (check-true (matrix-unitary? (circuit->matrix (qft n))))))
