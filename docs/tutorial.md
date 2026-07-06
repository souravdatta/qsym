# qsym Tutorial: Building Quantum Circuits from Scratch

## Introduction

This tutorial walks you through quantum simulation with **qsym** — a Racket library
that simulates quantum circuits on a classical computer. We start from first principles
(what is a qubit?) and end by implementing quantum teleportation, a protocol that
sends the complete state of a qubit using only classical bits.

Everything here runs as-is with `(require qsym)`.

---

## Part 1 — Qubits and States

### From classical bits to qubits

A classical bit is always either 0 or 1. In quantum computing, a qubit can be in a
**superposition** of both at once. Mathematically, a single qubit is a column vector

```
α|0⟩ + β|1⟩   where  |α|² + |β|² = 1
```

with complex amplitudes α and β. The only constraint is that the probabilities must
sum to 1. When you *measure* the qubit, it collapses: you see 0 with probability |α|²
and 1 with probability |β|².

### qsym's state representation

qsym stores an n-qubit state as an immutable vector of 2ⁿ complex amplitudes.
**Index k** corresponds to the basis state whose qubit values are the bits of k,
little-endian (qubit 0 = least-significant bit):

```
index 0 = |0 0 0…⟩   (all qubits are 0)
index 1 = |0 0 1…⟩   (qubit 0 is 1)
index 2 = |0 1 0…⟩   (qubit 1 is 1)
index 3 = |0 1 1…⟩   (qubits 0 and 1 are both 1)
```

Bit strings print **MSB-first** so qubit 0 is the rightmost character. This matches
Qiskit's convention: `"01"` means qubit 0 = 1, qubit 1 = 0.

### Creating states

```racket
(require qsym)

;; The n-qubit all-zero state |0…0⟩
(qubits 1)    ; single qubit |0⟩
(qubits 2)    ; two-qubit  |00⟩
(qubits 3)    ; three-qubit |000⟩

;; q0 is a named alias for the single-qubit |0⟩
q0

;; A specific basis state: |k⟩ has amplitude 1 at index k, 0 elsewhere
(basis-state 2 0)  ; |00⟩
(basis-state 2 1)  ; |01⟩  (qubit 0 = 1)
(basis-state 2 3)  ; |11⟩
```

### Inspecting states

```racket
;; Probability of measuring basis state k
(state-probability (qubits 2) 0)   ; => 1.0  (|00⟩ is certain)
(state-probability (qubits 2) 1)   ; => 0.0

;; Marginal probability that qubit q is 0 or 1
(qubit-probability (qubits 2) 0 0)  ; => 1.0  (qubit 0 is always 0)
(qubit-probability (qubits 2) 0 1)  ; => 0.0
```

### Tensor product of states

`t*` builds a joint state from two independent states:

```racket
;; |0⟩ ⊗ |0⟩  =  |00⟩
(t* q0 q0)

;; Equivalent to (qubits 2)
(equal? (t* q0 q0) (qubits 2))  ; amplitudes are == for pure basis states
```

---

## Part 2 — Gates

### What is a gate?

A quantum gate is a unitary matrix. "Unitary" means U†U = I — applying the gate and
then its inverse (conjugate transpose) brings you back to where you started. This is
why quantum computing is inherently reversible.

Applying gate U to state |ψ⟩ gives state U|ψ⟩. In code, qsym uses index-arithmetic
kernels (O(2ⁿ) per gate) rather than full 2ⁿ×2ⁿ matrix multiplication.

### Single-qubit gate constants

```racket
ID   ; identity — leaves the qubit unchanged
X    ; Pauli-X (bit flip): |0⟩ → |1⟩, |1⟩ → |0⟩
Y    ; Pauli-Y
Z    ; Pauli-Z (phase flip): |1⟩ → -|1⟩
H    ; Hadamard: |0⟩ → |+⟩ = (|0⟩+|1⟩)/√2
S    ; phase gate: |1⟩ → i|1⟩
T    ; π/8 gate: |1⟩ → e^{iπ/4}|1⟩
Sdg  ; S†    Tdg  ; T†
```

### Applying single-qubit gates to a state (gX, gH, …)

The `gX`, `gH`, etc. helpers apply a gate to qubit 0 of a 1-qubit state:

```racket
;; Flip |0⟩ to |1⟩
(gX q0)   ; quantum-state with amplitude 1 at index 1

;; Put |0⟩ into superposition
(gH q0)   ; amplitudes: 1/√2 at index 0, 1/√2 at index 1

;; H applied twice is identity (up to floating point)
(state-~= (gH (gH q0)) q0)   ; => #t
```

For parametric gates:

```racket
(gRx (* 2 pi) q0)   ; Rx(2π) ≈ -I  (global phase)
(gRz (/ pi 2) q0)   ; Rz(π/2) on |0⟩
```

### Two-qubit gate constants

```racket
CX    ; CNOT:  control=qubit 0, target=qubit 1
CY    ; controlled-Y
CZ    ; controlled-Z (symmetric phase gate)
CH    ; controlled-H
SWAP  ; swap qubit 0 and qubit 1
CCX   ; Toffoli (two controls, one target)
```

### The `at` constructor — explicit qubit placement

`at` places any gate at arbitrary qubit indices:

```racket
;; CNOT with control on qubit 2, target on qubit 0 (reversed order)
(at CX 2 0)

;; Hadamard on qubit 3 of a 5-qubit register
(at H 3)

;; Toffoli: controls on qubits 0 and 3, target on qubit 7
(at CCX 0 3 7)
```

The first argument after the gate is always the **first local qubit** of that gate.
For controlled gates the convention is: first qubit(s) = control(s), last qubit = target.

---

## Part 3 — Circuits

### Building a circuit

`make-circuit` takes a flat list of **layer items** and returns a `circuit` struct.
A circuit is also callable as a procedure — `(circ state)` applies it to a state.

The accepted layer item shapes are:

| Shape | Meaning |
|---|---|
| `(list g0 g1 …)` | Positional: gate `gi` on qubit `i`; all must be 1-qubit gates |
| `gate` | Bare: gate applied to qubits 0 … arity-1 |
| `(at gate q0 q1 …)` | Explicit qubit placement |
| `(measure q …)` | Measure qubit(s) into the classical register |
| `(when-bit c v item)` | Apply `item` only when classical bit `c` equals `v` |

### Bell pair

The canonical entangled two-qubit state:

```racket
(define bell
  (make-circuit (list (list H ID)    ; H on qubit 0, identity on qubit 1
                      (at CX 0 1))  ; CNOT: control=0, target=1
               #:qubits 2))

;; Apply to |00⟩
(define bell-state (bell (qubits 2)))

;; Check: amplitudes should be 1/√2 at |00⟩ and 1/√2 at |11⟩
(state-probability bell-state 0)   ; => 0.5  (index 0 = |00⟩)
(state-probability bell-state 3)   ; => 0.5  (index 3 = |11⟩)
(state-probability bell-state 1)   ; => 0.0
(state-probability bell-state 2)   ; => 0.0
```

Sample outcomes over many shots:

```racket
(counts bell-state #:shots 2048 #:seed 42)
; => #hash(("00" . 1021) ("11" . 1027))
; Only "00" and "11" appear — the qubits are entangled
```

Draw the circuit:

```racket
(print-circuit bell)
; q0 : ─[H]───●──
; q1 : [ID]───⊕──
```

### GHZ state (3-qubit entanglement)

```racket
(define ghz
  (make-circuit (list (list H ID ID)   ; H on qubit 0
                      (at CX 0 1)      ; CNOT q0→q1
                      (at CX 0 2))     ; CNOT q0→q2
               #:qubits 3))

(define ghz-state (ghz (qubits 3)))

;; Only |000⟩ and |111⟩ have non-zero probability
(state-probability ghz-state 0)   ; => 0.5  (|000⟩)
(state-probability ghz-state 7)   ; => 0.5  (|111⟩)

(counts ghz-state #:shots 2048 #:seed 1)
; => #hash(("000" . ~1024) ("111" . ~1024))
```

### Circuit combinators

```racket
;; Append two circuits (qubit counts must match)
(define circ-ab (circuit-append circ-a circ-b))

;; Repeat a circuit n times
(define repeated (circuit-repeat bell 3))

;; Inverse: reverse layers + invert each gate
(define bell-inv (circuit-inverse bell))

;; Check: circuit followed by its inverse ≈ identity
(state-~= (bell-inv (bell (qubits 2))) (qubits 2))  ; => #t
```

### run-state vs run-shot

| Function | Use when |
|---|---|
| `(run-state circ state)` | No measurements in the circuit |
| `(run-shot circ [state])` | Circuit has `measure` or `when-bit` layers |

`(circ state)` is a shorthand for `run-state` — it raises an error if the circuit
contains measurements.

---

## Part 4 — Measurement

### Exact distribution (no sampling)

```racket
;; Returns a hash: bit-string → |amplitude|²
(probabilities bell-state)
; => #hash(("00" . 0.5) ("11" . 0.5))
```

### Sampling from a state

```racket
;; No circuit, no collapse — just sample
(counts bell-state #:shots 4096 #:seed 7)
; => #hash(("00" . ~2048) ("11" . ~2048))

;; Reproducible with #:seed
(equal? (counts bell-state #:shots 100 #:seed 5)
        (counts bell-state #:shots 100 #:seed 5))   ; => #t
```

### Mid-circuit measurement and state collapse

`run-shot` executes a circuit that includes `measure` layers. Each measurement:
1. Samples an outcome from the qubit's probability distribution
2. Collapses the state (projects onto the measured value + renormalises)
3. Records the outcome in the classical register

```racket
(define measure-one
  (make-circuit (list (list H)
                      (measure 0))
               #:qubits 1 #:clbits 1))

(define-values (final-state cbits)
  (run-shot measure-one q0))

;; cbits is an immutable vector of classical bit values
(vector-ref cbits 0)   ; => 0 or 1  (randomly)

;; The final state is the post-measurement state (|0⟩ or |1⟩)
(state-probability final-state 0)   ; => 1.0 or 0.0
```

### Multi-shot execution

`run-shots` runs the circuit many times and tallies the classical register:

```racket
;; Bell circuit with measurement
(define bell+measure
  (make-circuit (list (list H ID)
                      (at CX 0 1)
                      (measure 0 1))
               #:qubits 2 #:clbits 2))

(run-shots bell+measure (qubits 2) #:shots 2048 #:seed 1)
; => #hash(("00" . ~1024) ("11" . ~1024))
```

### Marginal distribution and collapse

For advanced use, you can compute and apply measurement manually:

```racket
;; Probability distribution over qubits 0 and 1 jointly
(marginal-distribution bell-state '(0 1))
; => #(0.5 0.0 0.0 0.5)  ; P(00)=0.5, P(11)=0.5

;; Collapse: force qubit 0 = 0 and renormalise
(define collapsed (collapse-state bell-state '((0 . 0))))
(state-probability collapsed 0)   ; => 1.0  (forced to |00⟩)
(state-probability collapsed 3)   ; => 0.0
```

---

## Part 5 — Quantum Teleportation

Teleportation transmits the complete quantum state of a qubit from Alice to Bob using:
- One pair of entangled qubits (the Bell pair, shared in advance)
- Two classical bits sent over an ordinary channel

No quantum information travels over that channel — it is destroyed at Alice's end and
reconstructed at Bob's end.

### The circuit

```
q0 (Alice's payload) : ─────────●──[H]──[M]══════════════╗
q1 (Alice's half)    : ──[H]──●──⊕──────[M]════════╗      ║
q2 (Bob's half)      : ─────────⊕────────────[X]c1──[Z]c0──▶ payload arrives
c0                   : ══════════════════════╪════════╡1════
c1                   : ════════════════════╪══════════╡1══
```

Step by step:

1. **Prepare Bell pair**: H on q1, then CNOT q1→q2. Now q1 and q2 are entangled.
2. **Entangle payload with Alice's qubit**: CNOT q0→q1, then H on q0.
3. **Measure Alice's two qubits**: results go into classical bits c0 (from q0) and c1 (from q1).
4. **Correct Bob's qubit**: if c1=1, apply X to q2; if c0=1, apply Z to q2.

After step 4, q2 holds exactly the state q0 started with — teleported.

### The code

```racket
(require qsym)

(define teleport
  (make-circuit
   (list
    ;; 1. Prepare Bell pair on q1, q2
    (list ID H ID)
    (at CX 1 2)
    ;; 2. Entangle payload (q0) with Alice's qubit (q1)
    (at CX 0 1)
    (list H ID ID)
    ;; 3. Measure Alice's qubits into classical register
    (measure 0 1)
    ;; 4. Bob's corrections, conditioned on classical bits
    (when-bit 1 1 (at X 2))   ; if c1=1, flip Bob's qubit
    (when-bit 0 1 (at Z 2)))  ; if c0=1, phase-flip Bob's qubit
   #:clbits 2))
```

### Sending a payload

```racket
;; Payload: Rx(π/3) applied to |0⟩  ≈  cos(π/6)|0⟩ + i·sin(π/6)|1⟩
(define payload (gRx (/ pi 3) q0))

;; P(|1⟩) for the original payload
(qubit-probability payload 0 1)   ; => ≈ 0.25

;; Initial 3-qubit state: payload ⊗ |00⟩
(define initial (t* payload (qubits 2)))

;; Run one shot
(define-values (final-state cbits)
  (run-shot teleport initial))

(displayln (format "Alice's classical bits: ~a" (vector->list cbits)))

;; Bob's qubit is qubit 2; P(|1⟩) should match the original payload
(qubit-probability final-state 2 1)   ; => ≈ 0.25  ✓
```

### Statistical verification

Check teleportation fidelity over many different payload states:

```racket
(define (teleport-ok? theta)
  (define payload (gRx theta q0))
  (define initial (t* payload (qubits 2)))
  (define expected-p1 (qubit-probability payload 0 1))
  ;; Run 4096 shots, measure Bob's qubit too
  (define teleport+check
    (circuit-append
     teleport
     (make-circuit (list (measure (list 2 0))) #:qubits 3 #:clbits 2)))
  (define c (run-shots teleport+check initial #:shots 4096 #:seed 42))
  (define actual-p1
    (/ (for/sum ([(k v) c] #:when (string=? (substring k 0 1) "1")) v)
       4096))
  (< (abs (- actual-p1 expected-p1)) 0.03))   ; within 3%

(teleport-ok? 0)          ; => #t  (payload |0⟩, Bob always measures 0)
(teleport-ok? pi)         ; => #t  (payload |1⟩, Bob always measures 1)
(teleport-ok? (/ pi 2))  ; => #t  (payload |+⟩, ~50/50)
(teleport-ok? (/ pi 3))  ; => #t  (Rx(π/3), P(1)≈0.25)
```

### Why it works

- After step 2, the full 3-qubit state has been rewritten so that the payload's
  information is *spread* across entanglement correlations, not localised in q0.
- Measuring q0 and q1 gives Alice two random bits — but the exact values determine
  which of the four Bell states Bob's qubit q2 is in.
- Alice's two bits (sent classically) tell Bob exactly which unitary to apply to
  rotate q2 back to the original payload.
- The key insight: no measurement can distinguish the four Bell states from the
  outside, so no information about the payload leaks through the classical channel.

---

## Part 6 — Visualisation

### ASCII diagrams

```racket
(print-circuit teleport)
```

```
q0 : [ID]────────●───[H]──[M]──────────────
q1 : ─[H]───●────⊕──[ID]──[M]──────────────
q2 : [ID]───⊕───────[ID]───║───[X]────[Z]──
c0 : ══════════════════════╪════║══════╡1══
c1 : ══════════════════════╪═══╡1══════════
```

Wire conventions:
- `───` qubit wire,  `═══` classical wire
- `●` control dot,  `⊕` XOR target,  `[H]` gate box
- `[M]` measurement dropping `║` to the classical wire
- `╡1` reads classical bit value 1 to gate the conditioned operation

### Pict diagram (DrRacket / Scribble)

```racket
(define p (circuit->pict teleport))
;; p is a pict — composable, displayable in DrRacket
;; Save to PNG:
(require pict racket/draw)
(send (pict->bitmap p) save-file "/tmp/teleport.png" 'png)
```

### Histograms

```racket
(plot-histogram (counts bell-state #:shots 2048 #:seed 1))
(plot-state-probabilities bell-state)
```

---

## Part 7 — Going Further

### QFT and Grover are in `examples/`

```sh
racket examples/qft.rkt           # QFT on 4 qubits, checked against DFT matrix
racket examples/grover.rkt        # Grover search, 2 qubits, target |11⟩
racket examples/bb84.rkt          # BB84 quantum key distribution
racket examples/bernstein-vazirani.rkt
```

### Custom gates

```racket
;; From a unitary matrix
(define my-gate (matrix->gate 'my (matrix [[0 1] [1 0]])))

;; Inverse of any gate
(define H-inv (gate-inverse H))   ; H is self-inverse, so H-inv = H

;; Add a control qubit to any 1-qubit gate
(define controlled-H (controlled H))   ; equivalent to CH
```

### Quantum Fourier Transform

```racket
(define qft-4 (qft 4))    ; 4-qubit QFT circuit
(define iqft-4 (inverse-qft 4))

;; QFT |k⟩ = column k of the 16×16 DFT matrix (checked in examples/qft.rkt)
(define s (qft-4 (basis-state 4 5)))
```

### Performance note

The simulator uses O(2ⁿ) index-arithmetic kernels — no full 2ⁿ×2ⁿ tensor product
is ever constructed during `run-state` or `run-shot`. A 20-qubit, 30-gate circuit
runs in seconds on a laptop. `circuit->matrix` (used only for testing) *does* build
the full matrix and is exponential — avoid it for n > 12.

---

## Reference

| Topic | Functions |
|---|---|
| States | `zero-state`, `basis-state`, `qubits`, `q0`, `t*` |
| Inspect | `state-probability`, `qubit-probability`, `state-~=`, `probabilities` |
| Gates | `ID X Y Z H S T CX CZ SWAP CCX`, `RX RY RZ P U CP CRX` |
| Gate ops | `gate-inverse`, `controlled`, `matrix->gate` |
| Circuit | `make-circuit`, `at`, `measure`, `when-bit`, `circuit-append/repeat/inverse` |
| Simulate | `run-state`, `run-shot`, `run-shots`, `counts` |
| Visualise | `print-circuit`, `circuit->text`, `circuit->pict` |
| Plot | `plot-histogram`, `plot-state-probabilities` |

Full API reference: `raco docs qsym`
