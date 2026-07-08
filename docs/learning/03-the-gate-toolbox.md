# Part 3 — The Gate Toolbox

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

Classical computing has AND, OR, NOT. Quantum computing has its own basic
instruction set: **gates**. Today we meet the ones you'll use constantly, and
discover a rule with no classical counterpart — every gate must be
*reversible*.

## X — the quantum NOT

```racket
#lang racket
(require qsym)

(probabilities (gX q0))
; => #hash(("1" . 1.0))
```

X flips |0⟩ ↔ |1⟩. On a superposition it swaps the two amplitudes. Simple.

## Z — the gate that "does nothing"

Z leaves |0⟩ alone and multiplies |1⟩'s amplitude by −1:

```racket
(probabilities (gZ (gH q0)))
; => #hash(("0" . 0.4999999999999999) ("1" . 0.4999999999999999))
```

Same 50/50 distribution as before — Z changed nothing we can measure
directly. But remember chapter 2: signs matter when interference happens.
Sandwich Z between two Hadamards and it turns into a bit flip:

```racket
;; H·Z·H = X
(state-~= (gH (gZ (gH q0)))
          (gX q0))
; => #t
```

This is a pattern you'll see over and over: use H to move sign information
into measurable information and back. Phases are where quantum algorithms
hide their work.

## Rotations — the analog dial

X and Z are all-or-nothing. Rotation gates let you turn the dial
continuously. `RX(θ)` rotates the qubit by angle θ, moving probability
smoothly from |0⟩ to |1⟩:

```racket
(qubit-probability (gRx (/ pi 3) q0) 0 1)   ; => 0.25  — P(measure 1)
```

`(RX pi)` is a full bit flip; smaller angles give you any bias you want.
There are three of these — `RX`, `RY`, `RZ`, one per axis — and together they
can build *any* single-qubit operation. (What axes? Chapter 4 will literally
draw them.)

## The full starter kit

```racket
ID              ; do nothing (useful as a placeholder in layers)
X  Y  Z         ; Pauli gates: bit flip, both flips, phase flip
H               ; Hadamard: to/from superposition
S  T  Sdg  Tdg  ; smaller fixed phase rotations (and their inverses)
(RX θ) (RY θ) (RZ θ)   ; parametric rotations
CX  CZ  SWAP  CCX      ; multi-qubit gates — the stars of chapter 5
```

## Everything is reversible

Here's the rule with no classical analog. Classical gates destroy
information: knowing `AND(a, b) = 0` doesn't tell you the inputs. Quantum
mechanics doesn't allow that — every gate is a *unitary* transformation,
which is math-speak for "a rotation of the state that can always be undone".

qsym makes this concrete. Every gate has an exact inverse, and so does every
measurement-free circuit:

```racket
(define bell
  (make-circuit (list (list H ID) (at CX 0 1)) #:qubits 2))

;; Run the circuit, then its inverse: you're back where you started.
(state-~= ((circuit-inverse bell) (bell (qubits 2)))
          (qubits 2))
; => #t
```

`gate-inverse` inverts a single gate the same way. Some gates are their own
inverse (H, X, Z, CX — apply twice, get identity); others, like T, need their
dagger versions (Tdg).

Two consequences worth remembering:

- **No erasing.** A quantum circuit can't overwrite a qubit or copy one
  (the "no-cloning theorem"). Algorithms must be choreographed so garbage
  gets *uncomputed*, not discarded.
- **Measurement is the exception.** Measuring is the one irreversible thing
  you can do — it collapses superposition and throws information away. That's
  why circuits keep it for the very end (or use it very deliberately
  mid-circuit, as we'll see in chapter 6).

**Next time:** we stop imagining qubits and start *looking* at them — the
Bloch sphere, quantum computing's best picture.
