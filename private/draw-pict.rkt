#lang racket/base

;; Pict-based circuit renderer.
;; Reuses assign-columns / item-wire-span / gate-label from draw-text.rkt.
;;
;; Layout: same greedy column assignment as draw-text.rkt.
;; Each cell is a CELL-W × CELL-H pict; rows are stacked with vl-append,
;; columns are joined with hc-append.

(require pict
         racket/list
         "circuit.rkt"
         "gates.rkt"
         "draw-text.rkt")

(provide circuit->pict)

;; ---- layout constants -------------------------------------------------------

(define CELL-W   44)
(define CELL-H   32)
(define WIRE-Y   (/ CELL-H 2))
(define FONT-SIZE 11)

;; ---- basic pict helpers -----------------------------------------------------

(define (label-text s)
  (text s (cons 'bold "Courier") FONT-SIZE))

(define (gate-box-pict lbl)
  (define txt (label-text lbl))
  (define w (+ (pict-width txt) 8))
  (define h (+ (pict-height txt) 4))
  (cc-superimpose
   (filled-rectangle w h #:color "white" #:border-color "black" #:border-width 1)
   txt))

(define (control-dot-pict)
  (filled-ellipse 10 10 #:color "black"))

(define (xor-pict)
  ; ⊕: circle with + inside
  (define c (circle 12))
  (define cross
    (cc-superimpose
     (hline 10 1)
     (vline 1 10)))
  (cc-superimpose c cross))

(define (wire-pict w nq)
  ; horizontal wire across CELL-W; qubit=thin black, clbit=medium gray
  (if (< w nq)
      (colorize (hline CELL-W 1) "black")
      (colorize (hline CELL-W 2) "dimgray")))

(define (connector-pict)
  ; vertical line from top to bottom of cell
  (colorize (vline 1 CELL-H) "black"))

;; overlay sym at (dx, dy) on base pict
(define (overlay base sym dx dy)
  (pin-over base dx (max 0 dy) sym))

;; center sym vertically on the wire inside a cell of CELL-W × CELL-H
(define (cell-with-sym wire-p sym)
  (define base (pin-over (blank CELL-W CELL-H) 0 (- WIRE-Y 0.5) wire-p))
  (define dx (/ (- CELL-W (pict-width sym)) 2))
  (define dy (- WIRE-Y (/ (pict-height sym) 2)))
  (pin-over base dx (max 0 dy) sym))

;; idle cell: just the wire
(define (idle-cell w nq)
  (pin-over (blank CELL-W CELL-H) 0 (- WIRE-Y 0.5) (wire-pict w nq)))

;; connector cell: wire + vertical line down the center
(define (connector-cell w nq)
  (define base (idle-cell w nq))
  (pin-over base (/ CELL-W 2) 0 (connector-pict)))

;; ---- per-wire cell pict -----------------------------------------------------

;; make-cell: item wire-w nq -> pict (CELL-W × CELL-H)
(define (make-cell item w nq)
  (define wp (wire-pict w nq))
  (cond
    ;; ---- positional list ----
    [(list? item)
     (if (< w (length item))
         (cell-with-sym wp (gate-box-pict (gate-label (list-ref item w))))
         (idle-cell w nq))]

    ;; ---- bare gate ----
    [(gate? item)
     (define arity (gate-arity item))
     (if (< w arity)
         (let ([sym (if (and (> arity 1) (= w 0))
                        (control-dot-pict)
                        (gate-box-pict (gate-label item)))])
           (cell-with-sym wp sym))
         (idle-cell w nq))]

    ;; ---- gate-at ----
    [(gate-at? item)
     (define qs (gate-at-qubits item))
     (define g  (gate-at-gate item))
     (define lo (apply min qs))
     (define hi (apply max qs))
     (cond
       [(member w qs)
        (define pos (index-of qs w))
        (define sym
          (cond
            [(< pos (sub1 (gate-arity g)))  (control-dot-pict)]
            [(member (gate-name g) '(cx ccx)) (xor-pict)]
            [else (gate-box-pict (gate-label g))]))
        (cell-with-sym wp sym)]
       [(and (>= w lo) (<= w hi))
        (connector-cell w nq)]
       [else (idle-cell w nq)])]

    ;; ---- measure-at ----
    [(measure-at? item)
     (define qs  (measure-at-qubits item))
     (define cs  (measure-at-clbits item))
     (define q-lo (apply min qs))
     (define c-hi (apply max cs))
     (cond
       [(member w qs)
        (cell-with-sym wp (gate-box-pict "M"))]
       [(member (- w nq) cs)
        (cell-with-sym wp (label-text "╪"))]
       [(and (< w nq) (>= w q-lo))
        (connector-cell w nq)]
       [(and (>= w nq) (<= (- w nq) c-hi))
        (connector-cell w nq)]
       [else (idle-cell w nq)])]

    ;; ---- when-bit* ----
    [(when-bit*? item)
     (define cbit  (when-bit*-clbit item))
     (define cval  (when-bit*-value item))
     (define inner (when-bit*-item item))
     (define c-wire (+ nq cbit))
     (define-values (ilo ihi) (item-wire-span inner nq))
     (cond
       [(= w c-wire)
        (cell-with-sym wp (label-text (string-append "╡" (number->string cval))))]
       [(and (>= w ilo) (<= w ihi))
        (make-cell inner w nq)]
       [(and (> w ihi) (< w c-wire))
        (connector-cell w nq)]
       [else (idle-cell w nq)])]

    [else (idle-cell w nq)]))

;; ---- top-level --------------------------------------------------------------

;; circuit->pict: circuit -> pict
(define (circuit->pict circ)
  (define nq    (circuit-num-qubits circ))
  (define nc    (circuit-num-clbits circ))
  (define nw    (+ nq nc))
  (define assgn (assign-columns circ))
  (define ncols (if (null? assgn) 0
                    (add1 (apply max (map cdr assgn)))))

  ;; wire-label column (leftmost)
  (define label-col
    (apply vl-append 0
           (for/list ([w (in-range nw)])
             (define lbl (if (< w nq)
                             (format "q~a" w)
                             (format "c~a" (- w nq))))
             (define p (label-text lbl))
             (define cell (blank (+ (pict-width p) 10) CELL-H))
             (pin-over cell 4 (- WIRE-Y (/ (pict-height p) 2)) p))))

  ;; one pict column per layout column
  (define col-picts
    (for/list ([c (in-range ncols)])
      (apply vl-append 0
             (for/list ([w (in-range nw)])
               (define item-here
                 (for/or ([pair assgn])
                   (and (= (cdr pair) c)
                        (let-values ([(lo hi) (item-wire-span (car pair) nq)])
                          (and (>= w lo) (<= w hi) (car pair))))))
               (if item-here
                   (make-cell item-here w nq)
                   (idle-cell w nq))))))

  (apply hc-append 0 label-col col-picts))
