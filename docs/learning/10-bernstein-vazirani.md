# Part 10 — Bernstein–Vazirani: Reading a Secret in One Query

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

Last time, one oracle query told us a single yes/no fact about a hidden
function. Today the same circuit shape extracts **n bits of information** —
an entire hidden bit string — from one query. This is Bernstein–Vazirani,
and it's the cleanest demonstration of quantum parallelism plus
interference actually *paying out*.

## The problem

The oracle hides a secret n-bit string **s** and computes the dot product
mod 2:

```
f(x) = s·x = (s₀x₀ ⊕ s₁x₁ ⊕ … ⊕ sₙ₋₁xₙ₋₁)
```

Find s. Classically you need **n queries** — feed in `1000…`, `0100…`,
`0010…`, reading out one bit of s per call, and information theory says you
can't do better since each call returns a single bit. Quantumly: **one**.

## Why one query suffices

The setup is identical to Deutsch–Jozsa: ancilla in |−⟩, H on all inputs,
one oracle call, H on all inputs again. The oracle stamps (−1)^(s·x) onto
each branch |x⟩ — and here's the payoff: that particular pattern of signs
is exactly what the Hadamard transform produces when applied to the basis
state **|s⟩**. So the final H layer, being its own inverse, maps the state
*directly onto* |s⟩. Measure, and every qubit reads out its bit of the
secret with certainty.

Deutsch–Jozsa asked "are the signs all equal?" Bernstein–Vazirani asks the
sharper question "*which* sign pattern is this?" — and interference answers
exactly.

## The code

The oracle is beautifully simple: a CX from input qubit i to the ancilla,
for each i where sᵢ = 1.

```racket
#lang racket
(require qsym)

(define (oracle secret)
  (define n (length secret))
  (for/list ([b secret] [i (in-naturals)]
             #:when (= b 1))
    (at CX i n)))

(define (bv-circuit secret)
  (define n (length secret))
  (make-circuit
   (append
    (list (append (make-list n ID) (list X)))    ; ancilla → |1⟩
    (list (make-list (+ n 1) H))                  ; H everywhere
    (oracle secret)                               ; ONE query
    (list (append (make-list n H) (list ID))))    ; H on inputs
   #:qubits (+ n 1)))

(define secret '(1 1 0 0 1))   ; s₀=1 s₁=1 s₂=0 s₃=0 s₄=1

(define circ (bv-circuit secret))
(counts (circ (qubits 6)) #:shots 512 #:seed 1)
; => #hash(("010011" . 260) ("110011" . 252))
```

Reading the output (little-endian — qubit 0 is the rightmost character):
the leftmost character is the ancilla, still in superposition, so ignore
it. The remaining five characters are `10011` in both keys — read right to
left, that's qubit 0 = 1, qubit 1 = 1, qubit 2 = 0, qubit 3 = 0, qubit 4 = 1:

```
secret = (1 1 0 0 1)  ✓
```

Deterministic on the qubits that matter, in a single oracle call. Try a
longer secret — the circuit grows linearly and still needs exactly one
query.

## Where this is heading

Notice the recurring engine: **encode answers into phases, then use an
interference transform to convert phases into a readable bit string.** In
Bernstein–Vazirani that transform is the Hadamard layer. Replace it with a
more powerful cousin — the *quantum Fourier transform* — and the same engine
finds periods of functions, which is precisely how Shor's algorithm breaks
RSA. (qsym ships a QFT: see `examples/qft.rkt`.)

**Next time:** we drop the promise-problem training wheels. Grover's search
finds a marked item in an unsorted haystack quadratically faster than any
classical scan.
