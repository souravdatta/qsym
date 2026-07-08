# Part 6 — Measurement and Classical Control

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

Until now we've treated measurement as the thing that happens at the very
end. Today it becomes a first-class instruction: measure *inside* a circuit,
store the result in a classical bit, and make later gates conditional on it.
This is the last tool we need before building quantum teleportation.

## Measurement collapses

When you measure a qubit, two things happen: you get a classical bit, and
the quantum state **changes** — every branch inconsistent with the outcome
is deleted, and what's left is rescaled. There's no undo.

qsym's `measure` layer records outcomes into a classical register (declared
with `#:clbits`), and `run-shot` executes one full run:

```racket
#lang racket
(require qsym)

(define measure-one
  (make-circuit (list (list H)
                      (measure 0))     ; measure qubit 0 → classical bit 0
                #:qubits 1 #:clbits 1))

(define-values (final-state cbits) (run-shot measure-one q0))

(vector-ref cbits 0)                 ; => 0 or 1, at random
(state-probability final-state 0)    ; => 1.0 or 0.0 — no more superposition
```

Note the two return values: the post-measurement quantum state, and the
classical register. The state is consistent with the bits — if you measured
1, the qubit *is* now |1⟩.

For statistics, `run-shots` repeats the whole circuit and tallies the
classical register:

```racket
(run-shots measure-one q0 #:shots 1000 #:seed 42)
; => roughly #hash(("0" . 500) ("1" . 500))
```

## The quantum `if`: when-bit

`when-bit` applies a gate only if a classical bit has a given value. Here's
a tiny "echo" circuit: flip a quantum coin, measure it, then copy the result
onto a second qubit using classical control:

```racket
(define echo
  (make-circuit (list (list H ID)
                      (measure 0)              ; c0 ← qubit 0
                      (when-bit 0 1 (at X 1))  ; if c0 = 1, flip qubit 1
                      (measure 0 1))           ; read both
                #:qubits 2 #:clbits 2))

(run-shots echo (qubits 2) #:shots 1000 #:seed 7)
; => #hash(("00" . 494) ("11" . 506))
```

The two bits always agree — qubit 1 was steered by a *classical* bit that
didn't exist until mid-circuit. Real quantum hardware does exactly this
(it's called *feed-forward*), and it's the mechanism behind teleportation's
famous "corrections".

Compare with chapter 5: the Bell circuit produced the same 00/11 statistics
using entanglement. Same output distribution, completely different physics —
here there's no entanglement at all, just a measured coin and an `if`.

## Under the hood: collapse as a function

qsym exposes the projection step directly, which is handy for understanding
what measurement does to entangled states. Take the Bell pair and force
qubit 0 to be 0:

```racket
(define bell
  (make-circuit (list (list H ID) (at CX 0 1)) #:qubits 2))
(define bell-state (bell (qubits 2)))

(probabilities (collapse-state bell-state '((0 . 0))))
; => #hash(("00" . 1.0))
```

Measuring one qubit of a Bell pair decided *both*. The "11" branch was
deleted wholesale — that's what perfect correlation means mechanically.

## Where we stand

We now have every ingredient of the quantum toolbox:

- superposition (chapter 2) and interference,
- reversible gates (chapter 3),
- entanglement (chapter 5),
- measurement, collapse, and classical feed-forward (today).

**Next time** we compose all four into the most elegant protocol in quantum
information: teleporting a qubit with two classical bits.
