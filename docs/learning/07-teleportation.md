# Part 7 — Quantum Teleportation

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

Alice has a qubit in some state she may not even know. She wants Bob to have
it. She can't measure it (that destroys it), can't copy it (no-cloning
theorem, chapter 3), and has no quantum channel to send it through. All she
has is a **shared Bell pair** and a **phone**.

Teleportation solves this: the qubit's complete state is destroyed at
Alice's end and reappears at Bob's, at the cost of two classical bits. Let's
build it — it's only seven layers.

## The protocol

Three qubits: q0 is Alice's payload, q1 is Alice's half of the Bell pair,
q2 is Bob's half.

1. **Share entanglement**: make a Bell pair on q1, q2 (chapter 5).
2. **Entangle the payload** with Alice's half: CX from q0 to q1, then H on q0.
3. **Measure** q0 and q1 → two classical bits.
4. **Phone Bob the bits.** Bob applies X if c1 = 1 and Z if c0 = 1 (chapter
   6's `when-bit`).

After step 4, q2 *is* the payload.

```racket
#lang racket
(require qsym)

(define teleport
  (make-circuit
   (list
    ;; 1. Bell pair between Alice (q1) and Bob (q2)
    (list ID H ID)
    (at CX 1 2)
    ;; 2. Entangle the payload with Alice's half
    (at CX 0 1)
    (list H ID ID)
    ;; 3. Measure Alice's two qubits
    (measure 0 1)
    ;; 4. Bob's corrections, driven by the classical bits
    (when-bit 1 1 (at X 2))
    (when-bit 0 1 (at Z 2)))
   #:clbits 2))

(print-circuit teleport)
```

```
q0 : [ID]────────●───[H]──[M]──────────────
q1 : ─[H]───●────⊕──[ID]──[M]──────────────
q2 : [ID]───⊕───────[ID]───║───[X]────[Z]──
c0 : ══════════════════════╪════║══════╡1══
c1 : ══════════════════════╪═══╡1══════════
```

## Send something

Make a payload Bob couldn't guess — a partial rotation with a 25% chance of
measuring 1:

```racket
(define payload (gRx (/ pi 3) q0))
(qubit-probability payload 0 1)        ; => 0.25

;; Full input: payload ⊗ |00⟩
(define initial (t* payload (qubits 2)))

(define-values (final-state cbits) (run-shot teleport initial))

(vector->list cbits)                       ; => e.g. (0 1) — random every run
(qubit-probability final-state 2 1)        ; => 0.25  ✓ Bob has the payload
```

Run it repeatedly: Alice's bits come out different each time, but Bob's
qubit *always* ends with exactly the payload's statistics — not
approximately, exactly. The full state (amplitudes, phase and all) moved
from q0 to q2.

## Why this doesn't break physics

- **No cloning:** after Alice's measurement, q0 holds a plain 0 or 1 — the
  original is gone. The state was moved, never copied.
- **No faster-than-light:** until Bob receives c0 and c1 and applies his
  corrections, his qubit shows pure noise (its Bloch vector sits at the
  center of the sphere — chapter 5). The protocol is gated on a classical
  channel.
- **No information leak:** Alice's two bits are uniformly random regardless
  of the payload. An eavesdropper on the phone line learns nothing — the
  bits only say *which of four rotations* Bob must undo, not what the state
  is.

That last point is the beautiful one: a qubit has continuous parameters —
infinitely many possible states — yet teleporting it costs exactly **two
bits**. The entanglement carries everything else.

**Next time:** the same trick run backwards. Superdense coding — packing two
classical bits into a single transmitted qubit.
