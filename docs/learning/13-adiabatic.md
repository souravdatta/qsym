# Part 13 — Adiabatic Quantum Computing: Solving by Going Slowly

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

Every algorithm in this series has been a **circuit**: a choreographed
sequence of discrete gates. For the finale, meet a completely different
model — the one powering quantum annealers like D-Wave's machines. No logic,
no oracles. Just one rule: *change things slowly enough, and the system
solves the problem for you.*

## The idea

In physics, every system has an energy function (a **Hamiltonian**), and
left alone at low temperature it settles into its lowest-energy state — the
**ground state**. Many hard optimization problems (scheduling, SAT,
portfolio selection) can be encoded so that their answer *is* the ground
state of some Hamiltonian H_problem. Trouble is, finding that ground state
directly is as hard as the original problem.

The adiabatic recipe sidesteps this:

1. Start with an *easy* Hamiltonian H_easy whose ground state you can
   prepare trivially.
2. Interpolate: H(t) = (1−t)·H_easy + t·H_problem, sweeping t from 0 to 1
   **slowly**.
3. The **adiabatic theorem** guarantees that a system starting in the ground
   state and evolved slowly enough *stays* in the (moving) ground state.
   At t = 1, read out the answer.

The entire algorithm is: prepare, wait carefully, measure.

## A one-qubit demonstration

We'll sweep a single qubit from the ground state of an X-type Hamiltonian
(easy: it's |−⟩ = HX|0⟩, a state we can prepare with two gates) to the
ground state of a Z-type Hamiltonian (the "answer": |1⟩). A gate simulator
has no continuous time, so we *Trotterize*: chop the sweep into 100 slices,
each applying a small RX rotation (weight 1−t) and a small RZ rotation
(weight t):

```racket
#lang racket
(require qsym)

;; One RX+RZ slice per step; RX fades out as RZ fades in.
(define (adiabatic-gates angle)
  (flatten
   (for/list ([i (in-range 0.0 1.0 0.01)])
     (list (RX (* angle (- 1.0 i)))
           (RZ (* angle i))))))

;; X, H prepares |−⟩ — the ground state of the easy Hamiltonian.
(define sweep
  (make-circuit (append (list X H) (adiabatic-gates 30.0))))

(define final (sweep q0))

(state-probability final 1)   ; => 0.998 — the qubit found |1⟩
(state-probability final 0)   ; => 0.002
```

The qubit was never *told* to go to |1⟩ — no X gate, no explicit flip. It
simply tracked the slowly deforming energy landscape downhill, 200 tiny
rotations in a row, and arrived at the target ground state with 99.8%
probability.

## What happens if you rush

The adiabatic theorem's fine print is the word *slowly*. Redo the sweep in
5 slices instead of 100:

```racket
(define (fast-gates angle steps)
  (flatten
   (for/list ([i (in-range 0.0 1.0 (/ 1.0 steps))])
     (list (RX (* angle (- 1.0 i))) (RZ (* angle i))))))

(define rushed ((make-circuit (append (list X H) (fast-gates 30.0 5))) q0))
(state-probability rushed 0)   ; => 0.126 — 12.6% leaked to the wrong state
```

Rushing "shakes" the system into excited states — wrong answers. And here
lies the entire complexity story of adiabatic computing: how slow is slow
enough depends on the **minimum energy gap** between the ground state and
the first excited state during the sweep. For hard problem instances that
gap can shrink exponentially, demanding exponentially long sweeps. Adiabatic
quantum computing is provably *equivalent* in power to the circuit model —
it relocates the difficulty, it doesn't abolish it.

Real quantum annealers run exactly this scheme with thousands of coupled
qubits, where H_problem encodes an optimization objective and the readout is
a candidate solution.

## Series wrap-up

Thirteen chapters ago you installed Racket. Since then you've built
superposition and interference (2–4), entanglement (5), measurement and
feed-forward (6), teleportation and superdense coding (7–8), three genuine
quantum algorithms (9–11), physically-secured cryptography (12), and now a
second model of computation entirely. Everything ran on
[qsym](https://github.com/souravdatta/qsym) — go read its source: the whole
simulator is small, pure, and yours to extend. A good next step: open
`examples/qft.rkt`, then find out why the Fourier transform terrifies
cryptographers.
