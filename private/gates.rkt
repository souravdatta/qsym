#lang racket/base

;; Gate structs and the standard gate library.
;;
;; A gate is a name (symbol), arity (number of qubit slots), matrix (2^arity × 2^arity),
;; and params (list of real parameters, e.g. rotation angle — kept for inverse/drawing).
;;
;; Argument and matrix convention:
;;   (at gate q0 q1 ...) maps local qubit 0 -> q0, local qubit 1 -> q1, etc.
;;   Matrix indices are little-endian: bit i of the index = local qubit i.
;;   For controlled gates: first qubit in (at ...) = CONTROL, remaining = targets.
;;   So (at CX ctrl tgt), (at CCX ctrl1 ctrl2 tgt), etc.

(require math/matrix
         racket/math
         "linalg.rkt")

(provide
 (struct-out gate)
 ;; 1-qubit constants
 ID X Y Z H S Sdg T Tdg
 ;; 1-qubit parametric constructors
 RX RY RZ P U
 ;; 2-qubit constants
 CX CY CZ CH SWAP
 ;; 2-qubit parametric constructors
 CP CRX
 ;; 3-qubit constants
 CCX CSWAP
 ;; gate constructors
 matrix->gate
 gate-inverse
 controlled)

;; ---- struct ----------------------------------------------------------------

(struct gate (name arity matrix params) #:transparent)

;; ---- internal helpers -------------------------------------------------------

(define (make-gate name arity mat)
  (gate name arity mat '()))

(define (make-gate/params name arity mat params)
  (gate name arity mat params))

;; ---- 1-qubit gate matrices -------------------------------------------------

(define sqrt2-inv (/ 1.0 (sqrt 2.0)))

(define mat-ID  (identity-matrix 2))
(define mat-X   (matrix [[0 1] [1 0]]))
(define mat-Y   (matrix [[0 0-1i] [0+1i 0]]))
(define mat-Z   (matrix [[1 0] [0 -1]]))
(define mat-H   (matrix [[sqrt2-inv  sqrt2-inv]
                          [sqrt2-inv (- sqrt2-inv)]]))
(define mat-S   (matrix [[1 0] [0 +1i]]))
(define mat-Sdg (matrix [[1 0] [0 -1i]]))
(define mat-T   (matrix [[1 0] [0 (exp (* +1i (/ pi 4.0)))]]))
(define mat-Tdg (matrix [[1 0] [0 (exp (* -1i (/ pi 4.0)))]]))

;; ---- 1-qubit constants -----------------------------------------------------

(define ID  (make-gate 'id  1 mat-ID))
(define X   (make-gate 'x   1 mat-X))
(define Y   (make-gate 'y   1 mat-Y))
(define Z   (make-gate 'z   1 mat-Z))
(define H   (make-gate 'h   1 mat-H))
(define S   (make-gate 's   1 mat-S))
(define Sdg (make-gate 'sdg 1 mat-Sdg))
(define T   (make-gate 't   1 mat-T))
(define Tdg (make-gate 'tdg 1 mat-Tdg))

;; ---- 1-qubit parametric constructors ---------------------------------------

;; Rx(θ) = [[cos θ/2, -i sin θ/2], [-i sin θ/2, cos θ/2]]
(define (RX theta)
  (make-gate/params 'rx 1
    (let ([c (cos (/ theta 2.0))]
          [s (* -1i (sin (/ theta 2.0)))])
      (matrix [[c s] [s c]]))
    (list theta)))

;; Ry(θ) = [[cos θ/2, -sin θ/2], [sin θ/2, cos θ/2]]
(define (RY theta)
  (make-gate/params 'ry 1
    (let ([c (cos (/ theta 2.0))]
          [s (sin (/ theta 2.0))])
      (matrix [[c (- s)] [s c]]))
    (list theta)))

;; Rz(θ) = diag(e^{-iθ/2}, e^{iθ/2})
(define (RZ theta)
  (make-gate/params 'rz 1
    (matrix [[(exp (* -1i (/ theta 2.0))) 0]
             [0 (exp (* +1i (/ theta 2.0)))]])
    (list theta)))

;; P(θ) = [[1, 0], [0, e^{iθ}]]  (phase gate)
(define (P theta)
  (make-gate/params 'p 1
    (matrix [[1 0]
             [0 (exp (* +1i theta))]])
    (list theta)))

;; U(θ, φ, λ) — general single-qubit unitary
(define (U theta phi lam)
  (make-gate/params 'u 1
    (matrix [[(cos (/ theta 2.0))
              (* (- (exp (* +1i lam))) (sin (/ theta 2.0)))]
             [(* (exp (* +1i phi)) (sin (/ theta 2.0)))
              (* (exp (* +1i (+ phi lam))) (cos (/ theta 2.0)))]])
    (list theta phi lam)))

;; ---- 2-qubit gate matrices -------------------------------------------------
;;
;; Index encoding: k = q0 + 2*q1 (local qubit 0 = bit 0 = LSB).
;; For controlled gates: local q0 = CONTROL, local q1 = TARGET.
;;
;; Basis:  index 0 = q0=0,q1=0
;;         index 1 = q0=1,q1=0
;;         index 2 = q0=0,q1=1
;;         index 3 = q0=1,q1=1
;;
;; CX (control=q0, target=q1):
;;   q0=0 -> identity on q1
;;   q0=1 -> X on q1: flip q1
;;   |01⟩(idx 1) -> |11⟩(idx 3)   |11⟩(idx 3) -> |01⟩(idx 1)

(define mat-CX
  (matrix [[1 0 0 0]
           [0 0 0 1]
           [0 0 1 0]
           [0 1 0 0]]))

;; CY (control=q0, target=q1): Y = [[0,-i],[i,0]]
;;   |01⟩(1) -> i|11⟩(3)     |11⟩(3) -> -i|01⟩(1)
(define mat-CY
  (matrix [[1 0 0 0]
           [0 0 0 -1i]
           [0 0 1 0]
           [0 +1i 0 0]]))

;; CZ (control=q0, target=q1): symmetric — phase -1 only on |11⟩
(define mat-CZ
  (matrix [[1 0 0 0]
           [0 1 0 0]
           [0 0 1 0]
           [0 0 0 -1]]))

;; CH (control=q0, target=q1): H = [[h,h],[h,-h]]
;;   col 1 (q0=1,q1=0): H|0⟩ = h|0⟩+h|1⟩ → h*idx1 + h*idx3
;;   col 3 (q0=1,q1=1): H|1⟩ = h|0⟩-h|1⟩ → h*idx1 - h*idx3
(define mat-CH
  (matrix [[1 0         0 0]
           [0 sqrt2-inv 0 sqrt2-inv]
           [0 0         1 0]
           [0 sqrt2-inv 0 (- sqrt2-inv)]]))

;; SWAP: symmetric, swaps q0 and q1
;;   |01⟩(1) <-> |10⟩(2)
(define mat-SWAP
  (matrix [[1 0 0 0]
           [0 0 1 0]
           [0 1 0 0]
           [0 0 0 1]]))

;; ---- 2-qubit constants -----------------------------------------------------

(define CX   (make-gate 'cx   2 mat-CX))
(define CY   (make-gate 'cy   2 mat-CY))
(define CZ   (make-gate 'cz   2 mat-CZ))
(define CH   (make-gate 'ch   2 mat-CH))
(define SWAP (make-gate 'swap 2 mat-SWAP))

;; ---- 2-qubit parametric constructors ---------------------------------------

;; CP(θ): controlled-phase, control=q0, target=q1
;;   Only |11⟩(idx 3) picks up the phase.  (Symmetric gate.)
(define (CP theta)
  (make-gate/params 'cp 2
    (matrix [[1 0 0 0]
             [0 1 0 0]
             [0 0 1 0]
             [0 0 0 (exp (* +1i theta))]])
    (list theta)))

;; CRX(θ): controlled-Rx, control=q0, target=q1
;;   RX sub-block acts on odd-indexed states (q0=1).
(define (CRX theta)
  (make-gate/params 'crx 2
    (let ([c (cos (/ theta 2.0))]
          [s (* -1i (sin (/ theta 2.0)))])
      (matrix [[1 0 0 0]
               [0 c 0 s]
               [0 0 1 0]
               [0 s 0 c]]))
    (list theta)))

;; ---- 3-qubit gate matrices -------------------------------------------------
;;
;; Index k = q0 + 2*q1 + 4*q2.
;; CCX (Toffoli): control0=q0, control1=q1, target=q2... wait, that's wrong.
;;
;; Actually: (at CCX q0 q1 q2) means local-q0=first-arg, local-q1=second-arg, local-q2=third-arg.
;; Convention: control0=q0, control1=q1, target=q2.
;; Flip q2 when q0=1 AND q1=1:
;;   States where q0=1 AND q1=1: indices where bit0=1 AND bit1=1, i.e., k & 3 = 3.
;;   k=3  (q0=1,q1=1,q2=0) -> k=7  (q0=1,q1=1,q2=1)
;;   k=7  (q0=1,q1=1,q2=1) -> k=3

(define mat-CCX
  (list*->matrix
   '((1 0 0 0 0 0 0 0)
     (0 1 0 0 0 0 0 0)
     (0 0 1 0 0 0 0 0)
     (0 0 0 0 0 0 0 1)
     (0 0 0 0 1 0 0 0)
     (0 0 0 0 0 1 0 0)
     (0 0 0 0 0 0 1 0)
     (0 0 0 1 0 0 0 0))))

;; CSWAP (Fredkin): control=q0, swap-targets=q1,q2
;; Swap q1 and q2 when q0=1:
;;   k=3  (q0=1,q1=1,q2=0) <-> k=5  (q0=1,q1=0,q2=1)

(define mat-CSWAP
  (list*->matrix
   '((1 0 0 0 0 0 0 0)
     (0 1 0 0 0 0 0 0)
     (0 0 1 0 0 0 0 0)
     (0 0 0 0 0 1 0 0)
     (0 0 0 0 1 0 0 0)
     (0 0 0 1 0 0 0 0)
     (0 0 0 0 0 0 1 0)
     (0 0 0 0 0 0 0 1))))

;; ---- 3-qubit constants -----------------------------------------------------

(define CCX   (make-gate 'ccx   3 mat-CCX))
(define CSWAP (make-gate 'cswap 3 mat-CSWAP))

;; ---- gate constructors -----------------------------------------------------

;; matrix->gate: wrap an arbitrary unitary as a named gate.
(define (matrix->gate name mat)
  (unless (matrix-unitary? mat)
    (error 'matrix->gate "matrix is not unitary for gate ~a" name))
  (let ([n (matrix-num-rows mat)])
    (unless (= (matrix-num-cols mat) n)
      (error 'matrix->gate "matrix must be square for gate ~a" name))
    (define arity (inexact->exact (round (/ (log n) (log 2)))))
    (unless (= (expt 2 arity) n)
      (error 'matrix->gate "matrix size ~a is not a power of 2 for gate ~a" n name))
    (gate name arity mat '())))

;; gate-inverse: conjugate transpose; appends '†' to the name.
(define (gate-inverse g)
  (gate (string->symbol (string-append (symbol->string (gate-name g)) "†"))
        (gate-arity g)
        (matrix-adjoint (gate-matrix g))
        (gate-params g)))

;; controlled: add one control qubit as local qubit 0 (first arg in at).
;; Original qubits shift to local positions 1..k.
;;
;; New matrix M'[r,c]:
;;   Let ctrl_c = c & 1, sub_c = c >> 1 (old index from c)
;;   Let ctrl_r = r & 1, sub_r = r >> 1 (old index from r)
;;   If ctrl_c = 0: identity block -> (r == c) ? 1 : 0
;;   If ctrl_c = 1 and ctrl_r = 1: M_old[sub_r, sub_c]
;;   Otherwise: 0
(define (controlled g)
  (define old-k  (expt 2 (gate-arity g)))
  (define new-k  (* 2 old-k))
  (define old-mat (gate-matrix g))
  (define new-mat
    (build-matrix new-k new-k
                  (λ (r c)
                    (define ctrl-c (bitwise-and c 1))
                    (define sub-c  (arithmetic-shift c -1))
                    (define ctrl-r (bitwise-and r 1))
                    (define sub-r  (arithmetic-shift r -1))
                    (cond
                      [(= ctrl-c 0) (if (= r c) 1 0)]
                      [(= ctrl-r 1) (matrix-ref old-mat sub-r sub-c)]
                      [else 0]))))
  (gate (string->symbol (string-append "c" (symbol->string (gate-name g))))
        (+ (gate-arity g) 1)
        new-mat
        (gate-params g)))
