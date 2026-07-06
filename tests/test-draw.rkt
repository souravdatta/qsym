#lang racket/base

(require rackunit
         racket/string
         racket/list
         pict
         "../private/circuit.rkt"
         "../private/gates.rkt"
         "../private/draw-text.rkt"
         "../private/draw-pict.rkt")

;; Literal substring check (regexp-quote escapes special chars like "[")
(define (has? haystack needle)
  (regexp-match? (regexp-quote needle) haystack))

;; ============================================================
;; 1. Column-assignment unit tests
;; ============================================================

(define bell-circ
  (make-circuit (list (list H ID) (at CX 0 1)) #:qubits 2))

(define ghz-circ
  (make-circuit (list (list H ID ID)
                      (at CX 0 1)
                      (at CX 0 2))
                #:qubits 3))

(test-case "Bell: two items get two distinct columns"
  (define assgn (assign-columns bell-circ))
  (check-equal? (length assgn) 2)
  (check-equal? (cdr (first assgn))  0)
  (check-equal? (cdr (second assgn)) 1))

(test-case "GHZ: three items in three sequential columns (all share qubit 0)"
  (define assgn (assign-columns ghz-circ))
  (check-equal? (length assgn) 3)
  (check-equal? (cdr (first assgn))  0)
  (check-equal? (cdr (second assgn)) 1)
  (check-equal? (cdr (third assgn))  2))

(test-case "Independent gates pack into the same column"
  (define circ (make-circuit (list (at X 0) (at Z 1)) #:qubits 2))
  (define assgn (assign-columns circ))
  (check-equal? (cdr (first assgn))  0)
  (check-equal? (cdr (second assgn)) 0))

(test-case "item-wire-span: positional list"
  (define-values (lo hi) (item-wire-span (list H ID H) 3))
  (check-equal? lo 0)
  (check-equal? hi 2))

(test-case "item-wire-span: bare gate"
  (define-values (lo hi) (item-wire-span CX 2))
  (check-equal? lo 0)
  (check-equal? hi 1))

(test-case "item-wire-span: gate-at"
  (define-values (lo hi) (item-wire-span (at CX 1 3) 4))
  (check-equal? lo 1)
  (check-equal? hi 3))

(test-case "item-wire-span: measure-at maps to clbit wire"
  ; (measure 1) → qubit 1, clbit 1; with nq=3 clbit wire = 3+1=4
  (define-values (lo hi) (item-wire-span (measure 1) 3))
  (check-equal? lo 1)
  (check-equal? hi 4))

(test-case "item-wire-span: when-bit* spans inner item + clbit wire"
  ; (when-bit 0 1 (at X 2)) with nq=3: clbit 0 = wire 3; qubit 2 = wire 2
  (define-values (lo hi) (item-wire-span (when-bit 0 1 (at X 2)) 3))
  (check-equal? lo 2)
  (check-equal? hi 3))

;; ============================================================
;; 2. Golden-string tests for circuit->text
;; ============================================================

(test-case "circuit->text: Bell has qubit rows and gate symbols"
  (define txt (circuit->text bell-circ))
  (check-true (has? txt "q0"))
  (check-true (has? txt "q1"))
  (check-true (has? txt "[H]"))
  (check-true (has? txt "●"))
  (check-true (has? txt "⊕")))

(test-case "circuit->text: GHZ has control dots and XOR targets"
  (define txt (circuit->text ghz-circ))
  (check-true (has? txt "●"))
  (check-true (has? txt "⊕")))

(test-case "circuit->text: teleportation has measurement and clbit rows"
  (define teleport
    (make-circuit (list (list ID H ID)
                        (at CX 1 2)
                        (at CX 0 1)
                        (list H ID ID)
                        (measure 0 1)
                        (when-bit 1 1 (at X 2))
                        (when-bit 0 1 (at Z 2)))
                  #:clbits 2))
  (define txt (circuit->text teleport))
  (check-true (has? txt "q0"))
  (check-true (has? txt "q2"))
  (check-true (has? txt "c0"))
  (check-true (has? txt "c1"))
  (check-true (has? txt "[M]"))
  (check-true (has? txt "╡")))

(test-case "circuit->text: single-qubit gate sequence"
  (define circ (make-circuit (list H X Z) #:qubits 1))
  (define txt (circuit->text circ))
  (check-true (has? txt "[H]"))
  (check-true (has? txt "[X]"))
  (check-true (has? txt "[Z]")))

(test-case "circuit->text: returns non-empty string"
  (check-pred string? (circuit->text bell-circ))
  (check-true (> (string-length (circuit->text bell-circ)) 0)))

(test-case "circuit->text: each qubit gets its own line"
  (define txt (circuit->text bell-circ))
  (define lines (string-split txt "\n"))
  ; 2 qubits → 2 lines
  (check-equal? (length lines) 2))

(test-case "circuit->text: clbit rows appear for measured circuits"
  (define circ (make-circuit (list (measure 0)) #:qubits 2 #:clbits 1))
  (define txt (circuit->text circ))
  (define lines (string-split txt "\n"))
  ; 2 qubits + 1 clbit = 3 lines
  (check-equal? (length lines) 3)
  (check-true (has? txt "c0")))

;; ============================================================
;; 3. Pict smoke tests
;; ============================================================

(test-case "circuit->pict: Bell returns a pict with positive dimensions"
  (define p (circuit->pict bell-circ))
  (check-pred pict? p)
  (check-true (> (pict-width  p) 0))
  (check-true (> (pict-height p) 0)))

(test-case "circuit->pict: GHZ is taller than Bell"
  (check-true (> (pict-height (circuit->pict ghz-circ))
                 (pict-height (circuit->pict bell-circ)))))

(test-case "circuit->pict: deeper circuit is wider"
  (define shallow (make-circuit (list H) #:qubits 1))
  (define deep    (make-circuit (list H X H X) #:qubits 1))
  (check-true (> (pict-width (circuit->pict deep))
                 (pict-width (circuit->pict shallow)))))

(test-case "circuit->pict: teleportation pict is non-trivially wide"
  (define teleport
    (make-circuit (list (list ID H ID)
                        (at CX 1 2)
                        (at CX 0 1)
                        (list H ID ID)
                        (measure 0 1)
                        (when-bit 1 1 (at X 2))
                        (when-bit 0 1 (at Z 2)))
                  #:clbits 2))
  (define p (circuit->pict teleport))
  (check-pred pict? p)
  (check-true (> (pict-width p) 100)))
