# Part 4 — Seeing a Qubit: the Bloch Sphere

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

Amplitudes are two complex numbers — four real values, hard to picture. But
after removing redundancy (normalization, global phase), a single qubit's
state has exactly **two** degrees of freedom. Two degrees of freedom is a
point on a sphere. That sphere is the **Bloch sphere**, and it's the single
best mental image in quantum computing.

## The map

- **North pole** = |0⟩, **south pole** = |1⟩.
- Points on the **equator** are equal superpositions — same 50/50 statistics,
  differing only in *phase* (where around the equator they sit).
- Everything in between: latitude sets the 0/1 probabilities, longitude sets
  the phase.

Gates become rotations of the sphere: X is a half-turn around the x-axis
(north ↔ south — a bit flip), Z spins around the z-axis (changing phase but
not latitude — remember the gate that "did nothing" in chapter 3?), and H is
a half-turn about a diagonal axis that swaps the z-axis with the x-axis.

## Reading vectors in qsym

`bloch-vector` returns the (x y z) coordinates of a qubit:

```racket
#lang racket
(require qsym)

(bloch-vector q0 0)                  ; => (0 0 1.0)     north pole: |0⟩
(bloch-vector (gH q0) 0)             ; => (1.0 0 0.0)   equator, +x: |+⟩
(bloch-vector (gRx (/ pi 3) q0) 0)   ; => (0.0 -0.87 0.5)
```

That last one is worth a look: `RX(π/3)` rotated the vector π/3 of the way
down from the pole, in the y–z plane. Its z-coordinate, 0.5, encodes the
measurement bias directly: P(measure 1) = (1 − z)/2 = 0.25 — exactly the
number we computed in chapter 3.

## Drawing it

qsym renders the sphere as a picture — in DrRacket the result displays
inline:

```racket
(bloch-pict (gRx (/ pi 3) q0))   ; one qubit, drawn on the sphere

;; Or save to a file:
(require pict racket/draw)
(send (pict->bitmap (bloch-pict (gRx (/ pi 3) q0)))
      save-file "qubit.png" 'png)
```

There's also `bloch-pict*`, which draws every qubit of a multi-qubit state
side by side.

## A teaser: the vector that vanishes

The Bloch sphere pictures *one* qubit. What happens if we take a qubit that's
part of a two-qubit circuit — say, this one?

```racket
(define bell
  (make-circuit (list (list H ID) (at CX 0 1)) #:qubits 2))

(bloch-vector (bell (qubits 2)) 0)
; => (0 0 0.0)
```

The vector is **zero** — not on the sphere at all, but collapsed to the
center. The qubit, viewed alone, has no direction: it behaves like a coin
that is 50/50 in *every* basis, with no phase, no bias, nothing. Its state
isn't missing — it has moved into *correlations* with the other qubit, where
no single-qubit view can see it.

That circuit created **entanglement**, and it's next week's entire topic.

**Next time:** Bell pairs, GHZ states, and correlations that have no
classical explanation.
