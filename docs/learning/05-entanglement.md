# Part 5 — Entanglement: Correlations Without a Cause

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

So far our qubits have been loners. Today we wire two together and produce
the most famous state in quantum mechanics — the **Bell pair** — plus its
three-qubit big sibling. Entanglement is the resource behind teleportation,
superdense coding, and quantum cryptography, all of which we'll build in the
coming chapters.

## Two gates, one Bell pair

We need one new gate: **CX** (controlled-NOT). It acts on two qubits: if the
*control* qubit is 1, flip the *target*; otherwise do nothing. It's the
quantum XOR — and when the control is in superposition, it does both at once.

```racket
#lang racket
(require qsym)

(define bell
  (make-circuit (list (list H ID)    ; H on qubit 0
                      (at CX 0 1))   ; CX: control = qubit 0, target = qubit 1
                #:qubits 2))

(print-circuit bell)
; q0 : ─[H]───●──
; q1 : [ID]───⊕──
```

The `(at CX 0 1)` form places a multi-qubit gate explicitly: control on
qubit 0, target on qubit 1. Now run it on |00⟩:

```racket
(define bell-state (bell (qubits 2)))

(probabilities bell-state)
; => #hash(("00" . 0.4999999999999999) ("11" . 0.4999999999999999))
```

Follow the amplitudes: H puts qubit 0 into (|0⟩+|1⟩)/√2, so the pair is in
|00⟩ + |10⟩ (unnormalized). Then CX flips qubit 1 *only in the branch where
qubit 0 is 1*: |00⟩ + |11⟩. The two qubits no longer have individual states —
only the pair does.

## What makes this strange

Sample it:

```racket
(counts bell-state #:shots 2048 #:seed 42)
; => #hash(("00" . 1036) ("11" . 1012))
```

Each qubit alone is a fair coin. Together, they are **perfectly correlated**
— "01" and "10" never occur. Two synchronized coins isn't impressive by
itself (I could mail you two envelopes containing the same bit). The quantum
part: these qubits are correlated in *every measurement basis*, and Bell's
theorem proves no envelope scheme — no pre-agreed hidden values — can
reproduce those statistics. The correlation genuinely does not exist until
measurement.

Chapter 4's teaser showed the fingerprint of this: each qubit's Bloch vector
is at the **center** of the sphere —

```racket
(bloch-vector bell-state 0)   ; => (0 0 0.0)
(bloch-vector bell-state 1)   ; => (0 0 0.0)
```

Maximum ignorance about each part, complete knowledge of the whole.

## Scaling up: the GHZ state

Entanglement isn't limited to pairs. Chain one more CX and three qubits move
in lockstep:

```racket
(define ghz
  (make-circuit (list (list H ID ID)
                      (at CX 0 1)
                      (at CX 0 2))
                #:qubits 3))

(counts (ghz (qubits 3)) #:shots 2048 #:seed 1)
; => #hash(("000" . 1017) ("111" . 1031))
```

Eight possible outcomes, only two ever seen. The same pattern extends to any
number of qubits — and states like this are the starting point for quantum
error correction.

## One thing entanglement is *not*

Measuring qubit 0 instantly determines what qubit 1 will show, even if it's
far away — but this **cannot transmit information**. Whoever holds qubit 1
just sees a fair coin; the correlation is only visible when the two parties
later *compare notes over a classical channel*. No faster-than-light
messaging. What entanglement does enable is more subtle and, honestly, more
interesting.

**Next time:** measurement as a first-class citizen — collapse, measuring in
the middle of a circuit, and making gates conditional on earlier results.
That machinery is exactly what teleportation needs.
