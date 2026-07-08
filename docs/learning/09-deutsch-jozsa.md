# Part 9 — Deutsch–Jozsa: Your First Quantum Algorithm

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

Everything so far has been about *moving* quantum information. Today we
finally *compute* with it — with the algorithm that first proved a quantum
computer can beat a classical one at anything.

## The problem

You're given a black-box function `f` from n-bit strings to a single bit,
with a promise: `f` is either **constant** (same output for every input) or
**balanced** (outputs 0 on exactly half the inputs, 1 on the other half).
Decide which.

Classically, in the worst case you must evaluate `f` on 2ⁿ⁻¹ + 1 inputs —
check half the inputs plus one, because the first half might coincidentally
agree. The Deutsch–Jozsa algorithm decides with **one** evaluation. Not
fewer-on-average. One.

## The quantum trick

A quantum "black box" (an **oracle**) is a reversible circuit that computes
`f` into an extra qubit: it maps |x⟩|y⟩ to |x⟩|y ⊕ f(x)⟩. The algorithm:

1. Put the ancilla qubit into |−⟩ (that's H after X — the state with the
   minus sign from chapter 2).
2. Put all n input qubits into uniform superposition with H — the oracle now
   sees *every input at once*.
3. Call the oracle **once**. With the ancilla in |−⟩, the oracle writes each
   f(x) into the **sign** of branch |x⟩: amplitude (−1)^f(x).
4. Apply H to the input qubits again and measure. Interference does the
   rest: if all signs were equal (constant), every path back to |0…0⟩ adds
   constructively and you measure all zeros with certainty. If half the
   signs were flipped (balanced), those paths exactly cancel and |0…0⟩ has
   probability zero.

All-zeros → constant. Anything else → balanced. This is chapter 2's
"H, sign flip, H" pattern scaled up to n qubits.

## The code

```racket
#lang racket
(require qsym)

;; Oracle for f(x) = x0 ⊕ x1 ⊕ … (balanced): CX from each input to ancilla.
(define (oracle-balanced n)
  (for/list ([i (in-range n)])
    (at CX i n)))

;; Oracles for constant f: flip the ancilla always, or never.
(define (oracle-constant1 n) (list (at X n)))
(define (oracle-constant0 n) '())

(define (dj-circuit oracle n)
  (make-circuit
   (append
    (list (append (make-list n ID) (list X)))    ; ancilla → |1⟩
    (list (make-list (+ n 1) H))                  ; H everywhere (ancilla → |−⟩)
    (oracle n)                                    ; ONE oracle call
    (list (append (make-list n H) (list ID))))    ; H on inputs again
   #:qubits (+ n 1)))

(define n 4)

(define (constant? oracle)
  (define circ (dj-circuit oracle n))
  (define c (counts (circ (qubits (+ n 1))) #:shots 256 #:seed 1))
  ;; Input qubits are the rightmost n characters (ancilla is the MSB).
  (for/and ([k (hash-keys c)])
    (string=? (substring k 1) (make-string n #\0))))

(constant? oracle-constant0)   ; => #t
(constant? oracle-constant1)   ; => #t
(constant? oracle-balanced)    ; => #f
```

Three oracles, one query each, correct answer every time — 256 shots only to
demonstrate that the outcome is deterministic, not statistical.

## The honest fine print

Deutsch–Jozsa solves a contrived problem — and classically, *randomly
sampling* a few inputs answers it with overwhelming confidence anyway. Its
value isn't practical; it's that the exponential gap over exact classical
algorithms is **provable**, and its structure (superpose → phase-encode via
oracle → interfere → measure) is the skeleton of nearly every quantum
algorithm that followed, including Shor's.

**Next time:** the same skeleton, sharpened. Bernstein–Vazirani pulls an
entire hidden bit string out of an oracle in a single query.
