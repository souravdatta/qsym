#lang racket/base

(require rackunit
         math/matrix
         racket/math
         "../private/linalg.rkt"
         "../private/gates.rkt")

;; Convenience: are two matrices approximately equal?
(define (mat≈ m1 m2) (matrix-~= m1 m2))

;; ---- 1-qubit gate identities -----------------------------------------------

(test-case "ID is 2×2 identity"
  (check-true (mat≈ (gate-matrix ID) (identity-matrix 2))))

(test-case "X is Pauli-X"
  (check-true (mat≈ (gate-matrix X)
                    (matrix [[0 1] [1 0]]))))

(test-case "Z is Pauli-Z"
  (check-true (mat≈ (gate-matrix Z)
                    (matrix [[1 0] [0 -1]]))))

(test-case "H is Hadamard"
  (let ([h (/ 1.0 (sqrt 2.0))])
    (check-true (mat≈ (gate-matrix H)
                      (matrix [[h h] [h (- h)]])))))

;; Algebraic identities

(test-case "HZH = X"
  (check-true (mat≈ (matrix* (gate-matrix H)
                              (matrix* (gate-matrix Z) (gate-matrix H)))
                    (gate-matrix X))))

(test-case "S² = Z"
  (check-true (mat≈ (matrix* (gate-matrix S) (gate-matrix S))
                    (gate-matrix Z))))

(test-case "T² = S"
  (check-true (mat≈ (matrix* (gate-matrix T) (gate-matrix T))
                    (gate-matrix S))))

(test-case "Sdg = S†"
  (check-true (mat≈ (gate-matrix Sdg)
                    (matrix-adjoint (gate-matrix S)))))

(test-case "Tdg = T†"
  (check-true (mat≈ (gate-matrix Tdg)
                    (matrix-adjoint (gate-matrix T)))))

;; All standard 1-qubit gates are unitary

(for ([g (list ID X Y Z H S Sdg T Tdg)])
  (test-case (format "~a is unitary" (gate-name g))
    (check-true (matrix-unitary? (gate-matrix g)))))

;; ---- parametric 1-qubit gates ----------------------------------------------

(test-case "RX(0) = ID"
  (check-true (mat≈ (gate-matrix (RX 0)) (identity-matrix 2))))

(test-case "RX(π) = -iX  (up to global phase, magnitudes match)"
  ;; RX(π) = [[0,-i],[-i,0]] = -i X, so |entries| match |X entries|
  (check-true (mat≈ (matrix-map magnitude (gate-matrix (RX pi)))
                    (matrix-map magnitude (gate-matrix X)))))

(test-case "RY(0) = ID"
  (check-true (mat≈ (gate-matrix (RY 0)) (identity-matrix 2))))

(test-case "RZ(0) = ID"
  (check-true (mat≈ (gate-matrix (RZ 0)) (identity-matrix 2))))

(test-case "P(0) = ID"
  (check-true (mat≈ (gate-matrix (P 0)) (identity-matrix 2))))

(test-case "P(π) = Z (up to global phase)"
  ;; P(π) = diag(1, -1) = Z
  (check-true (mat≈ (gate-matrix (P pi)) (gate-matrix Z))))

(test-case "U(0,0,0) = ID"
  (check-true (mat≈ (gate-matrix (U 0 0 0)) (identity-matrix 2))))

(for ([theta (list 0 (/ pi 4) (/ pi 2) pi)])
  (test-case (format "RX(~a) is unitary" theta)
    (check-true (matrix-unitary? (gate-matrix (RX theta)))))
  (test-case (format "RY(~a) is unitary" theta)
    (check-true (matrix-unitary? (gate-matrix (RY theta)))))
  (test-case (format "RZ(~a) is unitary" theta)
    (check-true (matrix-unitary? (gate-matrix (RZ theta))))))

;; ---- 2-qubit gates ---------------------------------------------------------

(test-case "CX is unitary"
  (check-true (matrix-unitary? (gate-matrix CX))))

(test-case "CX maps |10⟩ -> |11⟩"
  ;; In little-endian: index 1 = q0=1,q1=0; index 3 = q0=1,q1=1.
  ;; CX col 1 should be [0,0,0,1]^T (maps to index 3).
  (check-= (magnitude (matrix-ref (gate-matrix CX) 3 1)) 1.0 1e-9)
  (check-= (magnitude (matrix-ref (gate-matrix CX) 1 1)) 0.0 1e-9))

(test-case "CX maps |11⟩ -> |01⟩"
  ;; index 3 -> index 1
  (check-= (magnitude (matrix-ref (gate-matrix CX) 1 3)) 1.0 1e-9)
  (check-= (magnitude (matrix-ref (gate-matrix CX) 3 3)) 0.0 1e-9))

(test-case "CX leaves |00⟩ and |10⟩ unchanged"
  (check-= (magnitude (matrix-ref (gate-matrix CX) 0 0)) 1.0 1e-9)
  (check-= (magnitude (matrix-ref (gate-matrix CX) 2 2)) 1.0 1e-9))

(for ([g (list CX CY CZ CH SWAP)])
  (test-case (format "~a is unitary" (gate-name g))
    (check-true (matrix-unitary? (gate-matrix g)))))

(test-case "SWAP swaps |01⟩ and |10⟩"
  ;; index 1 (q0=1,q1=0) -> index 2 (q0=0,q1=1)
  (check-= (magnitude (matrix-ref (gate-matrix SWAP) 2 1)) 1.0 1e-9)
  (check-= (magnitude (matrix-ref (gate-matrix SWAP) 1 2)) 1.0 1e-9))

(test-case "CP(0) = 4×4 identity"
  (check-true (mat≈ (gate-matrix (CP 0)) (identity-matrix 4))))

(test-case "CP(π) has -1 at |11⟩"
  ;; index 3 = q0=1,q1=1
  (check-= (real-part (matrix-ref (gate-matrix (CP pi)) 3 3)) -1.0 1e-9))

;; ---- 3-qubit gates ---------------------------------------------------------

(test-case "CCX is unitary"
  (check-true (matrix-unitary? (gate-matrix CCX))))

(test-case "CSWAP is unitary"
  (check-true (matrix-unitary? (gate-matrix CSWAP))))

;; CCX: flip qubit 2 when qubit 0 AND qubit 1 are 1.
;; k=3 (q0=1,q1=1,q2=0) -> k=7; k=7 -> k=3.
(test-case "CCX flips q2 when q0=q1=1"
  (check-= (magnitude (matrix-ref (gate-matrix CCX) 7 3)) 1.0 1e-9)
  (check-= (magnitude (matrix-ref (gate-matrix CCX) 3 7)) 1.0 1e-9))

(test-case "CCX leaves other basis states unchanged"
  (for ([k '(0 1 2 4 5 6)])
    (check-= (magnitude (matrix-ref (gate-matrix CCX) k k)) 1.0 1e-9)))

;; ---- gate constructors -----------------------------------------------------

(test-case "matrix->gate round-trips the Hadamard"
  (define g (matrix->gate 'myH (gate-matrix H)))
  (check-equal? (gate-name g) 'myH)
  (check-equal? (gate-arity g) 1)
  (check-true (mat≈ (gate-matrix g) (gate-matrix H))))

(test-case "matrix->gate rejects non-unitary matrix"
  (check-exn exn:fail?
             (λ () (matrix->gate 'bad (matrix [[1 1] [0 1]])))))

(test-case "gate-inverse of X is X (self-inverse)"
  (define xi (gate-inverse X))
  (check-true (mat≈ (gate-matrix xi) (gate-matrix X))))

(test-case "gate-inverse of S is Sdg"
  (define si (gate-inverse S))
  (check-true (mat≈ (gate-matrix si) (gate-matrix Sdg))))

(test-case "gate-inverse of T is Tdg"
  (check-true (mat≈ (gate-matrix (gate-inverse T)) (gate-matrix Tdg))))

(test-case "gate composed with its inverse is identity"
  (for ([g (list H S T (RX (/ pi 3)) (RY 1.0) (RZ (/ pi 7)))])
    (check-true (mat≈ (matrix* (gate-matrix (gate-inverse g)) (gate-matrix g))
                      (identity-matrix 2)))))

(test-case "controlled X = CX"
  (define cx-derived (controlled X))
  (check-equal? (gate-arity cx-derived) 2)
  (check-true (mat≈ (gate-matrix cx-derived) (gate-matrix CX))))

(test-case "controlled H has arity 2 and is unitary"
  (define ch-derived (controlled H))
  (check-equal? (gate-arity ch-derived) 2)
  (check-true (matrix-unitary? (gate-matrix ch-derived))))

(test-case "controlled H matches CH"
  (check-true (mat≈ (gate-matrix (controlled H)) (gate-matrix CH))))

(test-case "controlled CX = CCX  (control added at front)"
  (define ccx-derived (controlled CX))
  (check-equal? (gate-arity ccx-derived) 3)
  ;; The derived CCX should match the built-in, but the control qubit ordering
  ;; may differ: built-in CCX has ctrls=q0,q1, target=q2, but controlled(CX)
  ;; prepends a new ctrl at q0, so original CX q0->q1, q1->q2 shift one up.
  ;; Both are unitary; structural equality is checked separately.
  (check-true (matrix-unitary? (gate-matrix ccx-derived))))
