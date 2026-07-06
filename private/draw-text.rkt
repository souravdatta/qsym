#lang racket/base

;; ASCII circuit renderer.
;;
;; Layout: greedy left-packing — each layer item is assigned to the earliest
;; column where all of its wire slots (and the span between them) are free.
;; Wire indices: qubit q -> q; clbit c -> num-qubits + c.
;;
;; Conventions:
;;   qubit wire  : ─── (U+2500)   clbit wire: ═══ (U+2550)
;;   control     : ●              connector : │
;;   XOR target  : ⊕              measurement: [M] with ║ drop
;;   when-bit    : ╡v on clbit wire, gate symbol on qubit wire

(require racket/list
         racket/string
         "circuit.rkt"
         "gates.rkt")

(provide circuit->text
         print-circuit
         ;; exported for draw-pict.rkt
         assign-columns
         item-wire-span
         gate-label)

;; ============================================================
;; 1. Column-assignment
;; ============================================================

;; item-wire-span: item nq -> (values lo hi)
;; Inclusive wire indices that the item visually occupies.
;; Qubit q -> wire q; clbit c -> wire nq+c.
(define (item-wire-span item nq)
  (cond
    [(list? item)
     (values 0 (sub1 (length item)))]
    [(gate? item)
     (values 0 (sub1 (gate-arity item)))]
    [(gate-at? item)
     (define qs (gate-at-qubits item))
     (values (apply min qs) (apply max qs))]
    [(measure-at? item)
     (define lo (apply min (measure-at-qubits item)))
     (define hi (+ nq (apply max (measure-at-clbits item))))
     (values lo hi)]
    [(when-bit*? item)
     (define clo (+ nq (when-bit*-clbit item)))
     (define-values (ilo ihi) (item-wire-span (when-bit*-item item) nq))
     (values (min ilo clo) (max ihi clo))]
    [else (values 0 0)]))

;; assign-columns: circuit -> (listof (cons item col))
;; Greedy left-packing: each item placed in the earliest free column.
(define (assign-columns circ)
  (define nq (circuit-num-qubits circ))
  (define nc (circuit-num-clbits circ))
  (define nw (+ nq nc))
  (define next-col (make-vector nw 0))
  (for/list ([item (circuit-layers circ)])
    (define-values (lo hi) (item-wire-span item nq))
    (define col (for/fold ([c 0]) ([w (in-range lo (add1 hi))])
                  (max c (vector-ref next-col w))))
    (for ([w (in-range lo (add1 hi))])
      (vector-set! next-col w (add1 col)))
    (cons item col)))

;; ============================================================
;; 2. Gate label / symbol helpers
;; ============================================================

;; ~r: format a real to p decimal places
(define (~r x #:precision [p 2])
  (define s (number->string (exact->inexact x)))
  (define dot-pos
    (for/or ([i (in-range (string-length s))])
      (and (char=? (string-ref s i) #\.) i)))
  (if dot-pos
      (substring s 0 (min (string-length s) (+ dot-pos 1 p)))
      s))

;; gate-label: gate -> string  e.g. "H", "RX(0.50)"
(define (gate-label g)
  (define name (string-upcase (symbol->string (gate-name g))))
  (define params (gate-params g))
  (if (null? params)
      name
      (string-append name "("
                     (string-join (map (λ (p) (~r p #:precision 2)) params) ",")
                     ")")))

;; gate-symbol: which character/label to place at position pos of this gate
;; Gate names are lowercase symbols ('cx, 'ccx, etc.)
(define (gate-symbol g pos)
  (cond
    [(< pos (sub1 (gate-arity g))) "●"]                        ; control qubit
    [(member (gate-name g) '(cx ccx))  "⊕"]                   ; XOR target
    [(= (gate-arity g) 1)              (string-append "[" (gate-label g) "]")]
    [else                              (string-append "[" (gate-label g) "]")]))

;; ============================================================
;; 3. Column widths
;; ============================================================

(define CELL-MIN 5)

(define (item-cell-width item nq)
  (max CELL-MIN
       (cond
         [(list? item)
          (apply max (map (λ (g) (+ 2 (string-length (gate-label g)))) item))]
         [(gate? item)
          (+ 2 (string-length (gate-label item)))]
         [(gate-at? item)
          (define g (gate-at-gate item))
          (+ 2 (string-length (gate-label g)))]
         [(measure-at? item) 3]
         [(when-bit*? item)
          (item-cell-width (when-bit*-item item) nq)]
         [else 3])))

;; column-widths: list-of-(cons item col) nq -> hash col->width
(define (column-widths assignments nq)
  (define by-col (make-hash))
  (for ([pair assignments])
    (define col (cdr pair))
    (define w   (item-cell-width (car pair) nq))
    (hash-set! by-col col (max w (hash-ref by-col col 0))))
  by-col)

;; ============================================================
;; 4. Per-wire cell string
;; ============================================================

;; pad-center: string int char -> string of exactly w chars
(define (pad-center str w fill)
  (define len (string-length str))
  (if (>= len w)
      str
      (let* ([left  (quotient (- w len) 2)]
             [right (- w len left)])
        (string-append (make-string left fill) str (make-string right fill)))))

;; wire-cell: item wire nq col-width -> string of exactly cw chars
(define (wire-cell item w nq cw)
  (define q-idle (make-string cw #\─))
  (define c-idle (make-string cw #\═))
  (define (q-center s) (pad-center s cw #\─))
  (define (c-center s) (pad-center s cw #\═))
  (cond
    ;; ---- positional list ----
    [(list? item)
     (if (< w (length item))
         (q-center (string-append "[" (gate-label (list-ref item w)) "]"))
         q-idle)]

    ;; ---- bare gate ----
    [(gate? item)
     (if (< w (gate-arity item))
         (q-center (gate-symbol item w))
         q-idle)]

    ;; ---- gate-at ----
    [(gate-at? item)
     (define qs (gate-at-qubits item))
     (define g  (gate-at-gate item))
     (define lo (apply min qs))
     (define hi (apply max qs))
     (cond
       [(member w qs)
        (q-center (gate-symbol g (index-of qs w)))]
       [(and (>= w lo) (<= w hi))
        (q-center "│")]
       [else q-idle])]

    ;; ---- measure-at ----
    [(measure-at? item)
     (define qs  (measure-at-qubits item))
     (define cs  (measure-at-clbits item))
     (define q-lo (apply min qs))
     (define c-hi (apply max cs))
     (cond
       [(member w qs)              (q-center "[M]")]
       [(member (- w nq) cs)       (c-center "╪")]
       [(and (< w nq) (>= w q-lo)) (q-center "║")]   ; drop through qubit rows
       [(and (>= w nq) (<= (- w nq) c-hi)) (c-center "║")]  ; drop through clbit rows
       [(< w nq) q-idle]
       [else c-idle])]

    ;; ---- when-bit* ----
    [(when-bit*? item)
     (define cbit  (when-bit*-clbit item))
     (define cval  (when-bit*-value item))
     (define inner (when-bit*-item item))
     (define c-wire (+ nq cbit))
     (define-values (ilo ihi) (item-wire-span inner nq))
     (cond
       [(= w c-wire)
        (c-center (string-append "╡" (number->string cval)))]
       [(and (>= w ilo) (<= w ihi))
        (wire-cell inner w nq cw)]
       [(and (> w ihi) (< w c-wire))
        (if (< w nq) (q-center "║") (c-center "║"))]
       [(< w nq) q-idle]
       [else c-idle])]

    [else (if (< w nq) q-idle c-idle)]))

;; ============================================================
;; 5. Top-level renderer
;; ============================================================

;; circuit->text: circuit -> string
(define (circuit->text circ)
  (define nq    (circuit-num-qubits circ))
  (define nc    (circuit-num-clbits circ))
  (define nw    (+ nq nc))
  (define assgn (assign-columns circ))
  (define ncols (if (null? assgn) 0
                    (add1 (apply max (map cdr assgn)))))
  (define cw-map (column-widths assgn nq))
  (define (col-w c) (hash-ref cw-map c CELL-MIN))

  (define rows
    (for/list ([w (in-range nw)])
      (define prefix
        (if (< w nq)
            (format "q~a : " w)
            (format "c~a : " (- w nq))))
      (define cells
        (for/list ([c (in-range ncols)])
          (define item-here
            (for/or ([pair assgn])
              (and (= (cdr pair) c)
                   (let-values ([(lo hi) (item-wire-span (car pair) nq)])
                     (and (>= w lo) (<= w hi) (car pair))))))
          (define cw (col-w c))
          (if item-here
              (wire-cell item-here w nq cw)
              (if (< w nq)
                  (make-string cw #\─)
                  (make-string cw #\═)))))
      (string-append prefix (apply string-append cells))))

  (string-join rows "\n"))

;; print-circuit: circuit -> void
(define (print-circuit circ)
  (displayln (circuit->text circ)))
