# Part 11 — Grover's Search: Amplifying the Answer

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

Deutsch–Jozsa and Bernstein–Vazirani (chapters 9–10) solved promise problems
— elegant, but artificial. Grover's algorithm attacks a task every developer
knows: **unstructured search**. Given N items and an oracle that recognizes
the one you want, find it. Classically: N/2 checks on average. Grover: about
**√N**. For a database of a trillion items, that's a million steps instead
of half a trillion.

## The idea: amplitude amplification

Start with all N basis states in uniform superposition — each has amplitude
1/√N. Measuring now would be a random guess. Grover *iterates* two moves:

1. **Oracle**: flip the **sign** of the target's amplitude (phases again —
   invisible to measurement, decisive under interference).
2. **Diffusion**: reflect every amplitude about the *average* amplitude.

Picture the bar chart: after the oracle, the target's bar points down, which
drags the average slightly below the others. Reflecting about the average
then shrinks every ordinary bar a little and throws the target's bar *up
past* the average — taller than it started. Repeat, and the target's
probability grows with each round, peaking after ~(π/4)√N iterations.

## The 2-qubit case: one iteration, certainty

With n = 2 qubits, N = 4, and a single Grover iteration takes the target
from probability 0.25 to **exactly 1**. We'll mark |11⟩:

- The oracle is just **CZ** — it flips the sign of the |11⟩ branch and
  nothing else.
- The diffusion operator is H's, X's, another CZ, undone in reverse: a
  reflection about the uniform state.

```racket
#lang racket
(require qsym)

(define grover-2q
  (make-circuit
   (list (list H H)   ; uniform superposition: every item at 25%
         CZ            ; oracle: mark |11⟩ with a phase flip
         ;; diffusion: reflect about the average
         (list H H)
         (list X X)
         CZ
         (list X X)
         (list H H))
   #:qubits 2))

(define result (grover-2q (qubits 2)))

;; Before amplification, |11⟩ sat at 0.25:
(state-probability ((make-circuit (list (list H H)) #:qubits 2) (qubits 2)) 3)
; => 0.25

;; After one Grover iteration:
(state-probability result 3)
; => 1.0 (up to float error)

(counts result #:shots 1024 #:seed 1)
; => #hash(("11" . 1024))
```

1024 shots, 1024 hits. One oracle call, guaranteed answer — a classical
searcher checking one of four items succeeds 25% of the time.

To search for a different target, change only the oracle: sandwich the CZ
with X on whichever qubits should be 0 (e.g. `(list X ID)`, CZ,
`(list X ID)` marks |10⟩). The diffusion stage never changes.

## Scaling honestly

For larger n, you repeat the oracle + diffusion pair ~(π/4)√N times — qsym's
`circuit-repeat` combinator exists for exactly this. Two caveats worth
knowing:

- **Overshooting is real.** The success probability oscillates like a sine
  wave; iterate past the peak and it *falls*. You must stop at the right
  count.
- **Quadratic, not exponential.** Grover provably can't be beaten for black
  box search — √N is optimal. The dramatic exponential speedups (Shor)
  need problem structure to exploit.

Still, "square-root any brute-force search" is remarkably general: it
applies to SAT solving, collision finding, and inverting hash functions —
one reason post-quantum cryptography doubles symmetric key lengths.

**Next time:** quantum mechanics as a *defensive* technology. BB84 key
distribution — an eavesdropper can't listen without leaving fingerprints,
and we'll simulate her getting caught.
