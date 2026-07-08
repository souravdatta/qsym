# Quantum Computing with qsym — A Learning Series

A gradual introduction to quantum computing for developers, using
[qsym](https://github.com/souravdatta/qsym) — a quantum circuit simulator
written in Racket. No physics degree required: every concept is introduced
with runnable code, and every chapter is short enough to read over coffee.

Each chapter is self-contained and sized for a short blog post. Read them in
order the first time — the concepts build on each other.

| # | Chapter | You will learn |
|---|---------|----------------|
| 1 | [Getting Started](01-getting-started.md) | Install Racket + qsym, run your first quantum program |
| 2 | [Superposition](02-superposition.md) | What a qubit really is, and why it isn't just a probabilistic bit |
| 3 | [The Gate Toolbox](03-the-gate-toolbox.md) | The basic operations of quantum computing, and why they're all reversible |
| 4 | [Seeing a Qubit: the Bloch Sphere](04-bloch-sphere.md) | A picture worth 2ⁿ amplitudes |
| 5 | [Entanglement](05-entanglement.md) | Bell pairs, GHZ states, and correlations with no classical explanation |
| 6 | [Measurement and Classical Control](06-measurement.md) | Collapse, mid-circuit measurement, and quantum `if` statements |
| 7 | [Quantum Teleportation](07-teleportation.md) | Send a qubit using two classical bits |
| 8 | [Superdense Coding](08-superdense-coding.md) | Teleportation's mirror image: two bits in one qubit |
| 9 | [Deutsch–Jozsa](09-deutsch-jozsa.md) | Your first quantum algorithm — one query beats 2ⁿ⁻¹+1 |
| 10 | [Bernstein–Vazirani](10-bernstein-vazirani.md) | Extract a secret bit string in a single query |
| 11 | [Grover's Search](11-grover-search.md) | Amplitude amplification: finding a needle quadratically faster |
| 12 | [BB84 Quantum Key Distribution](12-bb84.md) | Cryptography where eavesdropping is physically detectable |
| 13 | [Adiabatic Quantum Computing](13-adiabatic.md) | A completely different model: computing by going slowly |

## Conventions used throughout

- qsym is **little-endian, Qiskit-compatible**: qubit 0 is the least-significant
  bit of a basis-state index, and bit strings print MSB-first, so qubit 0 is the
  **rightmost** character. `"01"` means qubit 0 = 1, qubit 1 = 0.
- Sampling functions take a `#:seed` argument so every run in these chapters is
  reproducible. Change the seed (or drop it) to see different randomness.
- Every code block runs as-is after `(require qsym)`.
