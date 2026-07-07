#lang racket/base

(require rackunit
         racket/math
         math/matrix
         pict
         "../private/state.rkt"
         "../private/gates.rkt"
         "../private/circuit.rkt"
         "../private/simulator.rkt"
         "../private/bloch.rkt")

(define (~= a b) (< (abs (- a b)) 1e-9))

(define (bloch~= state q expected)
  (for/and ([got (bloch-vector state q)] [want expected])
    (~= got want)))

;; ============================================================
;; 1. Bloch vectors of known states
;; ============================================================

(test-case "|0⟩ points to the north pole (0,0,1)"
  (check-true (bloch~= q0 0 '(0 0 1))))

(test-case "|1⟩ points to the south pole (0,0,-1)"
  (check-true (bloch~= (gX q0) 0 '(0 0 -1))))

(test-case "|+⟩ = H|0⟩ points along +x (1,0,0)"
  (check-true (bloch~= (gH q0) 0 '(1 0 0))))

(test-case "|-⟩ = HX|0⟩ points along -x (-1,0,0)"
  (check-true (bloch~= (gH (gX q0)) 0 '(-1 0 0))))

(test-case "|i⟩ = SH|0⟩ points along +y (0,1,0)"
  (check-true (bloch~= (gS (gH q0)) 0 '(0 1 0))))

(test-case "Rx(π/2)|0⟩ points along -y (0,-1,0)"
  (check-true (bloch~= (gRx (/ pi 2) q0) 0 '(0 -1 0))))

(test-case "Bell pair: each qubit is maximally mixed (0,0,0)"
  (define bell ((make-circuit (list (list H ID) (at CX 0 1)) #:qubits 2)
                (qubits 2)))
  (check-true (bloch~= bell 0 '(0 0 0)))
  (check-true (bloch~= bell 1 '(0 0 0))))

(test-case "Product state |0⟩⊗|+⟩: qubits keep their own vectors"
  ;; qubit 0 = |+⟩ (via H), qubit 1 = |0⟩ — no entanglement
  (define st ((make-circuit (list (list H ID)) #:qubits 2) (qubits 2)))
  (check-true (bloch~= st 0 '(1 0 0)))
  (check-true (bloch~= st 1 '(0 0 1))))

;; ============================================================
;; 2. Density matrix properties
;; ============================================================

(test-case "density matrix has unit trace"
  (define rho (qubit-density-matrix (gH q0) 0))
  (check-true (~= (real-part (+ (matrix-ref rho 0 0) (matrix-ref rho 1 1)))
                  1.0)))

(test-case "density matrix is Hermitian: rho01 = conj(rho10)"
  (define rho (qubit-density-matrix (gS (gH q0)) 0))
  (check-true (< (magnitude (- (matrix-ref rho 0 1)
                               (conjugate (matrix-ref rho 1 0))))
                 1e-9)))

(test-case "pure state: Bloch vector has unit length"
  (define v (bloch-vector (gRx 0.7 q0) 0))
  (check-true (~= (sqrt (for/sum ([c v]) (* c c))) 1.0)))

;; ============================================================
;; 3. Pict smoke tests
;; ============================================================

(test-case "bloch-pict returns a pict with positive dimensions"
  (define p (bloch-pict q0))
  (check-pred pict? p)
  (check-true (> (pict-width p) 0))
  (check-true (> (pict-height p) 0)))

(test-case "bloch-pict works for the mixed (entangled) case"
  (define bell ((make-circuit (list (list H ID) (at CX 0 1)) #:qubits 2)
                (qubits 2)))
  (check-pred pict? (bloch-pict bell 0)))

(test-case "bloch-pict* renders one sphere per qubit"
  (define ghz ((make-circuit (list (list H ID ID) (at CX 0 1) (at CX 0 2))
                             #:qubits 3)
               (qubits 3)))
  (define p1 (bloch-pict* ghz))
  (define p2 (bloch-pict* (qubits 2)))
  (check-pred pict? p1)
  ;; 3 spheres wider than 2 spheres
  (check-true (> (pict-width p1) (pict-width p2))))
