# Part 2 — Superposition: What a Qubit Really Is

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

Last time we flipped a quantum coin. Today we look inside it. The punchline:
a qubit in superposition is **not** "a bit that's 50% likely to be 1". It's
something stranger, and one short experiment will prove it.

## Amplitudes, not probabilities

A classical bit is 0 or 1. A qubit is a pair of complex numbers (α, β) —
called **amplitudes** — attached to the two outcomes:

```
α·|0⟩ + β·|1⟩      with  |α|² + |β|² = 1
```

When you measure, you see 0 with probability |α|² and 1 with probability
|β|². So far this sounds like probability with extra steps. The difference:
amplitudes can be **negative** (and complex), and that changes everything.

In qsym, `q0` is the single-qubit state |0⟩, and `gH` applies the Hadamard
gate to it:

```racket
#lang racket
(require qsym)

;; |+⟩ = H|0⟩: amplitudes 1/√2 and 1/√2
(define plus (gH q0))

(probabilities plus)
; => #hash(("0" . 0.4999999999999999) ("1" . 0.4999999999999999))

(state-probability plus 0)   ; => ~0.5
(state-probability plus 1)   ; => ~0.5
```

`probabilities` gives the exact distribution — no sampling. For the
experimental version, `counts` samples it like real hardware would:

```racket
(counts plus #:shots 1000 #:seed 42)
; => #hash(("0" . 493) ("1" . 507))
```

## The experiment that kills the "hidden coin" theory

Suppose a qubit after H were just a hidden classical coin — already secretly
0 or 1, we just don't know which. Then applying H **again** should keep it
50/50: randomizing a random coin gives a random coin.

Let's try:

```racket
(define plus-again (gH (gH q0)))

(probabilities plus-again)
; => #hash(("0" . 1.0))
```

Applying the "randomizer" twice gives a **certain** 0. Every time. The
hidden-coin theory is dead.

What actually happened is **interference**. H sends:

```
|0⟩ → (|0⟩ + |1⟩)/√2
|1⟩ → (|0⟩ − |1⟩)/√2      ← note the minus sign
```

Apply H to |+⟩ and expand: the |0⟩ contributions add up
(constructive interference) while the |1⟩ contributions arrive with opposite
signs and **cancel** (destructive interference). Probabilities can't cancel —
they're non-negative. Amplitudes can. That minus sign, invisible to any
single measurement, is the entire source of quantum computing's power. Every
algorithm in this series is at heart a scheme for making wrong answers cancel
and right answers add.

You can confirm the round trip programmatically (never compare floats with
`equal?` — qsym ships a tolerant comparator):

```racket
(state-~= (gH (gH q0)) q0)   ; => #t
```

## Scaling up: n qubits, 2ⁿ amplitudes

A register of n qubits carries one amplitude for **every** n-bit string —
2ⁿ complex numbers evolving together:

```racket
(qubits 3)          ; |000⟩ — 8 amplitudes, all weight on index 0
(basis-state 3 5)   ; |101⟩ — qubits 0 and 2 are 1 (index 5 = 0b101)
```

This is why simulating quantum computers classically gets hard fast — 30
qubits already means a billion amplitudes — and why a machine that
manipulates all of them at once is interesting.

One convention to memorize now, because it shows up everywhere: qsym (like
Qiskit) is **little-endian**. Qubit 0 is the least-significant bit, so in a
printed bit string qubit 0 is the *rightmost* character.

**Next time:** the gate toolbox — X, Z, rotations, and why every quantum
operation is reversible.
