# Part 1 — Getting Started: Your First Quantum Program

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

Quantum computing has a reputation problem: most introductions start with two
semesters of linear algebra. This series takes a different route — we'll learn
by **running code**, using qsym, a small quantum simulator written in Racket.
By the end of the series you'll have built quantum teleportation, a provably
eavesdrop-proof key exchange, and a quantum search algorithm — all on your
laptop.

Today: install everything and flip a truly random coin.

## Step 1 — Install Racket

Racket is a modern Lisp with a batteries-included IDE called DrRacket.
Download the installer for your OS from
[download.racket-lang.org](https://download.racket-lang.org) and run it.
That's it — DrRacket comes bundled.

On Linux you can also use your package manager, e.g. `sudo apt install racket`.

## Step 2 — Install qsym from GitHub

**In DrRacket:** open *File → Install Package…*, paste

```
https://github.com/souravdatta/qsym.git
```

and click **Install**. DrRacket fetches the package, compiles it, and builds
its documentation.

**Or from a terminal:**

```sh
raco pkg install --auto https://github.com/souravdatta/qsym.git
```

## Step 3 — Flip a quantum coin

Classical programs fake randomness with pseudo-random generators. A qubit
gives you the real thing. Type this into DrRacket and hit **Run**:

```racket
#lang racket
(require qsym)

;; One qubit, one gate: H (Hadamard) puts the qubit into an
;; equal superposition of 0 and 1.
(define coin (make-circuit (list (list H)) #:qubits 1))

;; Apply the circuit to a fresh qubit (which starts as |0⟩)...
(define flipped (coin (qubits 1)))

;; ...and measure it 1000 times.
(counts flipped #:shots 1000 #:seed 42)
```

Output:

```racket
#hash(("0" . 493) ("1" . 507))
```

Roughly half heads, half tails. Three things just happened:

1. `(qubits 1)` created a qubit in the state **|0⟩** — quantum notation for
   "definitely 0".
2. The **H gate** transformed it into a *superposition*: a state that is not
   0, not 1, but a precise combination of both.
3. `counts` simulated measuring the qubit 1000 times. Each measurement forces
   the qubit to pick a side — and in this state, it picks each side with
   probability exactly ½.

The `#:seed 42` makes the run reproducible — drop it and you'll get slightly
different tallies every time, like a real experiment.

## What a circuit is

The `make-circuit` call above is the pattern we'll use for the whole series:
a circuit is a **list of layers**, each layer saying which gates act on which
qubits, applied left to right. You can always ask qsym to draw one:

```racket
(print-circuit coin)
; q0 : ─[H]──
```

One wire (qubit 0), one gate. Our circuits will grow, but they'll never stop
being this: values you can build, combine, print, and apply like functions.

## Why this coin is special

A pseudo-random coin flip is deterministic — with the internal state of the
generator you could predict every flip. A measured qubit in superposition is
random *by the laws of physics*: there is no hidden variable to peek at (a
fact known as Bell's theorem, which we'll actually touch in chapter 5). Our
simulator uses a seeded RNG to *imitate* that randomness, but on real quantum
hardware this program is a perfect entropy source.

**Next time:** what superposition actually is — amplitudes, probabilities, and
the first genuinely quantum surprise: interference.
