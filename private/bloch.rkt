#lang racket/base

;; Bloch sphere diagrams for single qubits of an n-qubit state.
;;
;; Physics: tracing out all other qubits gives a 2x2 reduced density matrix
;; rho for the chosen qubit.  Its Pauli expectations form the Bloch vector:
;;   x = Tr(rho X) = 2 Re(rho01)
;;   y = Tr(rho Y) = -2 Im(rho01)
;;   z = Tr(rho Z) = rho00 - rho11
;; |r| = 1 for a pure (unentangled) qubit; |r| < 1 signals entanglement or
;; mixedness — a maximally entangled qubit sits at the center (|r| = 0).
;;
;; Rendering: an orthographic-style pict — sphere outline, dashed equator,
;; x/y/z axes, and the Bloch vector as an arrow.  Composes with circuit->pict.

(require math/matrix
         racket/math
         racket/class
         racket/draw
         pict
         "state.rkt")

(provide qubit-density-matrix
         bloch-vector
         bloch-pict
         bloch-pict*)

;; ---- reduced density matrix -------------------------------------------------

;; qubit-density-matrix: state q -> 2x2 matrix
;; Partial trace over all qubits except q:
;;   rho_ab = sum over basis pairs (k with bit q = a, same k with bit q = b)
;;            of psi[k_a] * conj(psi[k_b])
(define (qubit-density-matrix state q)
  (define n    (quantum-state-num-qubits state))
  (define N    (expt 2 n))
  (define amps (quantum-state-amplitudes state))
  (define step (expt 2 q))
  (define-values (r00 r01 r10 r11)
    (for/fold ([r00 0] [r01 0] [r10 0] [r11 0])
              ([base (in-range N)]
               #:when (= (bitwise-and base step) 0))
      (define a0 (vector-ref amps base))            ; qubit q = 0
      (define a1 (vector-ref amps (+ base step)))   ; qubit q = 1
      (values (+ r00 (* a0 (conjugate a0)))
              (+ r01 (* a0 (conjugate a1)))
              (+ r10 (* a1 (conjugate a0)))
              (+ r11 (* a1 (conjugate a1))))))
  (matrix [[r00 r01] [r10 r11]]))

;; ---- Bloch vector -----------------------------------------------------------

;; bloch-vector: state q -> (list x y z)
;; Pauli expectation values of qubit q's reduced density matrix.
(define (bloch-vector state q)
  (define rho (qubit-density-matrix state q))
  (define r01 (matrix-ref rho 0 1))
  (define r00 (matrix-ref rho 0 0))
  (define r11 (matrix-ref rho 1 1))
  (list (* 2.0 (real-part r01))
        (* -2.0 (imag-part r01))
        (real-part (- r00 r11))))

;; ---- rendering --------------------------------------------------------------

;; Oblique projection: y right, z up, x toward the viewer (down-left).
;; Returns screen offsets from the sphere center for a unit-sphere point.
(define (project x y z R)
  (values (+ (* R y)      (* R -0.35 x))
          (+ (* R (- z))  (* R  0.35 x))))

;; bloch-pict: state [q] -> pict
;; Draw qubit q of the state on a Bloch sphere.
(define (bloch-pict state [q 0] #:size [size 180])
  (define v  (bloch-vector state q))
  (define bx (car v))
  (define by (cadr v))
  (define bz (caddr v))
  (define r-len (sqrt (+ (* bx bx) (* by by) (* bz bz))))
  (define R  (* 0.40 size))
  (define caption-h 18)
  (define cx (/ size 2.0))
  (define cy (/ size 2.0))

  (define (draw dc0 dx dy)
    (define old-pen   (send dc0 get-pen))
    (define old-brush (send dc0 get-brush))
    (define old-font  (send dc0 get-font))
    (define old-text  (send dc0 get-text-foreground))
    (define (at-x x) (+ dx cx x))
    (define (at-y y) (+ dy cy y))

    (send dc0 set-brush (new brush% [style 'transparent]))

    ;; sphere outline
    (send dc0 set-pen (new pen% [color "black"] [width 1]))
    (send dc0 draw-ellipse (+ dx (- cx R)) (+ dy (- cy R)) (* 2 R) (* 2 R))

    ;; equator: dashed ellipse squashed by the projection tilt
    (send dc0 set-pen (new pen% [color "gray"] [width 1] [style 'short-dash]))
    (define eq-h (* 2 R 0.35))
    (send dc0 draw-ellipse (+ dx (- cx R)) (+ dy (- cy (/ eq-h 2))) (* 2 R) eq-h)

    ;; axes: +x (front, down-left), +y (right), +z (up)
    (define-values (px py) (project 1.0 0.0 0.0 R))
    (define-values (yx yy) (project 0.0 1.0 0.0 R))
    (define-values (zx zy) (project 0.0 0.0 1.0 R))
    (send dc0 set-pen (new pen% [color "gray"] [width 1] [style 'dot]))
    (send dc0 draw-line (at-x (- px)) (at-y (- py)) (at-x px) (at-y py))
    (send dc0 draw-line (at-x (- yx)) (at-y (- yy)) (at-x yx) (at-y yy))
    (send dc0 draw-line (at-x (- zx)) (at-y (- zy)) (at-x zx) (at-y zy))

    ;; axis labels
    (send dc0 set-font (make-font #:size 10 #:family 'modern))
    (send dc0 set-text-foreground (make-color 80 80 80))
    (send dc0 draw-text "|0⟩" (at-x (+ zx 3))  (at-y (- zy 14)))
    (send dc0 draw-text "|1⟩" (at-x (+ zx 3))  (at-y (- (- zy) 2)))
    (send dc0 draw-text "y"   (at-x (+ yx 2))  (at-y (- yy 12)))
    (send dc0 draw-text "x"   (at-x (- px 12)) (at-y (- py 2)))

    ;; Bloch vector
    (cond
      [(< r-len 1e-9)
       ;; maximally mixed: dot at center
       (send dc0 set-brush (new brush% [color "firebrick"] [style 'solid]))
       (send dc0 set-pen (new pen% [color "firebrick"] [width 1]))
       (send dc0 draw-ellipse (- (at-x 0) 3) (- (at-y 0) 3) 6 6)]
      [else
       (define-values (vx vy) (project bx by bz R))
       (send dc0 set-pen (new pen% [color "firebrick"] [width 2]))
       (send dc0 draw-line (at-x 0) (at-y 0) (at-x vx) (at-y vy))
       ;; arrowhead: two short strokes back from the tip
       (define ang (atan vy vx))
       (define head 7.0)
       (for ([da (list (+ ang (* 5/6 pi)) (- ang (* 5/6 pi)))])
         (send dc0 draw-line
               (at-x vx) (at-y vy)
               (at-x (+ vx (* head (cos da))))
               (at-y (+ vy (* head (sin da))))))])

    ;; caption: qubit index and vector length
    (send dc0 set-font (make-font #:size 10 #:family 'modern))
    (send dc0 set-text-foreground (make-color 0 0 0))
    (define caption (format "q~a  |r|=~a" q (real->decimal-string r-len 2)))
    (define-values (tw th td ta) (send dc0 get-text-extent caption))
    (send dc0 draw-text caption
          (+ dx (/ (- size tw) 2))
          (+ dy size 1))

    (send dc0 set-pen old-pen)
    (send dc0 set-brush old-brush)
    (send dc0 set-font old-font)
    (send dc0 set-text-foreground old-text))

  (dc draw size (+ size caption-h)))

;; bloch-pict*: state -> pict
;; Bloch spheres for every qubit of the state, side by side.
(define (bloch-pict* state #:size [size 180])
  (define n (quantum-state-num-qubits state))
  (apply hc-append 12
         (for/list ([q (in-range n)])
           (bloch-pict state q #:size size))))
