# qsym — Production-Ready Quantum Simulation Library in Racket

## Implementation Plan

This document is a self-contained plan for rewriting **qsym** into a production-quality,
extensible quantum computing *simulation* library in Racket. It is written to be executed
with fresh context: everything the implementer needs to know about the current code, the
target design, and the phased path there is in this file.

---

## 1. Goal and Scope

Build a quantum simulation library at par with *basic* Qiskit, covering:

- **State-vector simulation** of n-qubit circuits (scope is simulation only — no hardware
  backends, no transpilation to real devices, no noise models in the initial phases).
- **A single, unified circuit representation** (the current repo has two dialects —
  the raw layer-list style in `qsym.rkt` and the s-expression `qlang.rkt` DSL.
  **`qlang.rkt` is removed; the raw layer-list style is kept and upgraded** —
  same shape, new capabilities. One representation, one API).
- **Measurement done right**: full measurement, *partial* measurement of selected qubits
  with state collapse, classical registers, and **classically-conditioned gates**
  (Qiskit's `c_if`) so quantum teleportation and similar protocols are expressible.
- **Visualization**: histogram plots of measurement counts (via `plot`), and circuit
  diagram drawing — ASCII first, `pict`-based graphical diagrams in a later phase.
- **Extensibility**: users can define custom gates from matrices or from sub-circuits,
  build controlled/inverse versions of any gate, and compose circuits.
- **A worked algorithm/example suite**: teleportation, superdense coding,
  Bernstein–Vazirani, Deutsch–Jozsa, Grover, QFT, BB84, adiabatic evolution.

### Non-goals (explicitly out of scope)

- Noise/density-matrix simulation, hardware backends, OpenQASM import/export,
  pulse-level anything, transpiler optimization passes.
- Third-party dependencies. **Only Racket standard distribution libraries**:
  `math/matrix`, `math/array`, `math/base`, `plot`, `pict`, `racket/draw`,
  `rackunit`, `racket/contract`, `scribble`.

### Style mandates (apply to every phase)

- **SICP/Scheme flavor**: small pure functions, explicit recursion or `for/fold` where it
  reads naturally, data as plain structs and lists. Prefer *simple, longer* code over
  clever, dense code.
- **Immutability**: no `set!`, no mutable hashes/vectors in public-facing code paths.
  Internal hot loops may use local mutation only when it is provably local (e.g., building
  a fresh vector before freezing it), and this must be invisible to callers.
- **Prefer standard `math` library types** (e.g., `Matrix`, `Array`) over hand-rolled
  numerics where the fit is natural; hand-roll only where it is significantly simpler or
  asymptotically better (see §4.2 on gate application).
- Every public function gets a contract (`racket/contract`) and a short doc comment.
- `#lang racket/base` + explicit requires in library modules (keeps load time down);
  `#lang racket` is fine in examples.

---

## 2. Current State (what exists today)

Files in the repo before this plan is executed:

| File | Lines | Role | Fate |
|---|---|---|---|
| `qsym.rkt` | 306 | Core: qubits, gates, tensor products, `make-circuit`, measurement, counts, histogram, `gate-matrix` from classical functions, QFT, rotation gates | Superseded — ideas ported into the new modules |
| `qlang.rkt` | 129 | Second dialect: `def-circuit`/`def-layer` s-expr DSL, `sv-simulator`, crude ASCII drawing | **Deleted** |
| `bb84_simple.rkt` | 117 | BB84 example | Rewritten against new API |
| `ex_1_superdense.rkt` | 93 | Superdense coding example | Rewritten |
| `ex_2_vazirani_bernstein.rkt` | 71 | Bernstein–Vazirani example | Rewritten |
| `ex_3_adiabatic.rkt` | 65 | Adiabatic evolution example | Rewritten |
| `README.md`, `qsym_tutorial.md` | — | Docs referencing both dialects | Rewritten in final phase |

### Known defects and design problems to fix (do not carry these forward)

1. **Measurement granularity bug** (`qsym.rkt:102-109`): `measure-mat` scales
   probabilities to percentages and rolls `(random 100)` — an *integer* — so outcome
   probabilities are quantized to 1% and small amplitudes can be unreachable or
   distorted. Fix: sample with `(random)` (a real in [0,1)) against exact cumulative
   probabilities.
2. **Exponential blowup by construction**: `make-circuit` tensors every layer into a
   full 2^n × 2^n matrix and multiplies it against the state. A 1-qubit gate on a
   20-qubit register costs O(4^n) this way. Fix: apply gates directly to the state
   vector via index arithmetic — O(2^n) per 1- or 2-qubit gate (see §4.2).
3. **Mutation**: `tensor*`'s helper `list->mat` and `counts` use `set!` and mutable
   hashes. Replace with `for/fold` and immutable hashes.
4. **Two endianness conventions**: `G*` (Qiskit order) vs `nG*` (native order).
   Pick **one**: little-endian, Qiskit-compatible — qubit 0 is the least-significant
   bit of a basis-state label. Document it once, use it everywhere (state indexing,
   measurement bit strings, circuit drawing, histogram labels).
5. **No partial measurement / no classical control**: BB84 works around it by keeping
   single qubits in a list; teleportation cannot be written at all. The new core makes
   these first-class (§4.4, §4.5).
6. **`random-seed` leaks into examples**: reproducibility should be a documented
   feature (seed parameter on the sampler), not a global side effect sprinkled in
   example files.

---

## 3. Target Repository Layout

Make qsym a proper multi-collection Racket package so `raco pkg install` and
`(require qsym)` work.

```
qsym/
├── info.rkt                     ; package metadata, deps: base, math-lib, plot-gui-lib,
│                                ;   plot-lib, pict-lib, rackunit-lib (build)
├── main.rkt                     ; (require qsym) — re-exports the public API
├── private/
│   ├── linalg.rkt               ; complex linear algebra helpers over math/matrix:
│   │                            ;   tensor product, matrix exponent helpers, ~= comparison
│   ├── state.rkt                ; quantum-state struct + amplitude access + init states
│   ├── gates.rkt                ; gate struct, standard gate library, gate constructors
│   ├── circuit.rkt              ; circuit IR: instruction & circuit structs, builders,
│   │                            ;   composition, inverse, controlled, custom gates
│   ├── simulator.rkt            ; state-vector execution engine, gate application kernels
│   ├── measurement.rkt          ; sampling, partial measurement/collapse, counts
│   ├── draw-text.rkt            ; ASCII circuit renderer
│   ├── draw-pict.rkt            ; pict-based circuit renderer (Phase 5)
│   ├── plot.rkt                 ; histogram + state-probability plotting
│   └── bloch.rkt                ; Bloch sphere diagrams (post-plan extension)
├── examples/
│   ├── teleportation.rkt
│   ├── superdense.rkt
│   ├── bernstein-vazirani.rkt
│   ├── deutsch-jozsa.rkt
│   ├── grover.rkt
│   ├── qft.rkt
│   ├── bb84.rkt
│   └── adiabatic.rkt
├── tests/
│   ├── test-linalg.rkt
│   ├── test-state.rkt
│   ├── test-gates.rkt
│   ├── test-circuit.rkt
│   ├── test-simulator.rkt
│   ├── test-measurement.rkt
│   ├── test-conditional.rkt     ; teleportation as an end-to-end test
│   ├── test-draw.rkt
│   └── test-bloch.rkt           ; Bloch vector math + pict smoke tests
├── scribblings/
│   └── qsym.scrbl               ; Phase 6 reference docs
├── README.md
└── Plan.md                      ; this file
```

Notes:
- `private/` modules `provide` freely among themselves; `main.rkt` curates the public
  surface with `contract-out`. Users require only `qsym`.
- Old files `qsym.rkt`, `qlang.rkt`, `ex_*.rkt`, `bb84_simple.rkt` are deleted once
  their replacements exist (end of Phase 4).

---

## 4. Core Design

### 4.1 Data types (all immutable structs, `#:transparent`)

```racket
;; A quantum state: n qubits, 2^n complex amplitudes.
;; amplitudes is an immutable vector of complex numbers, little-endian indexing:
;; (vector-ref amplitudes k) is the amplitude of basis state |k⟩ where bit i of k
;; is the value of qubit i.
(struct quantum-state (num-qubits amplitudes))

;; A gate: name (symbol, for drawing), arity (# of qubit slots),
;; matrix (a 2^arity × 2^arity Matrix from math/matrix), and params
;; (list of reals, e.g. rotation angle — kept for drawing/inverse).
(struct gate (name arity matrix params))

;; Layer items beyond plain gates (constructed by `at`, `measure`, `when-bit`
;; below — users write the constructor forms, not the structs):
(struct gate-at    (gate qubits))       ; gate applied at explicit qubit indices
(struct measure-at (qubits clbits))     ; measure qubits into classical bits
(struct when-bit*  (clbit value item))  ; run item iff classical bit = value

;; A circuit: register sizes + a list of LAYERS (see §4.4 for layer shapes).
;; Has prop:procedure so (circ input-state) runs it directly, exactly like
;; today's make-circuit result.
(struct circuit (num-qubits num-clbits layers))
```

Design rationale:
- **The circuit representation is the current raw dialect, upgraded — not replaced.**
  A circuit is still a list of layers built with ordinary `list` / `append` /
  `make-list` / `for/list`, and is still *applied to an input state* like a function.
  What changes: gates become small structs (with their matrices inside) instead of
  bare matrices, three new layer items (`at`, `measure`, `when-bit`) cover what the
  old dialect couldn't express, and the simulator interprets layers efficiently
  instead of tensoring them into 2^n × 2^n matrices. `qlang` is still deleted; the
  raw dialect *is* the one dialect, now capable enough to not need a second one.
- The state's amplitude store is a plain immutable Racket vector rather than a
  `math/matrix` column matrix, because the simulator's hot path is indexed pair-access
  (§4.2), which matrices make slow and awkward. `math/matrix` remains the type for
  *gate* matrices, custom-gate construction, tensor products, and all algebra where it
  fits naturally.

### 4.2 Simulator: gate application by index arithmetic

This is the one place the plan mandates a specific algorithm, because it is the
difference between a toy and a usable simulator.

To apply a 1-qubit gate `[[a b] [c d]]` on qubit `t` of an n-qubit state: for every
pair of basis indices `(i0, i1)` that differ only in bit `t`
(`i1 = i0 + 2^t`, iterate `i0` over indices with bit `t` = 0):

```
new[i0] = a*old[i0] + b*old[i1]
new[i1] = c*old[i0] + d*old[i1]
```

O(2^n) per gate. The 2-qubit kernel is the same idea over groups of 4 indices
(bits `t1`, `t2`); a general k-qubit kernel handles groups of 2^k. Implement:

- `apply-gate-1q : matrix target state -> state`
- `apply-gate-2q : matrix target1 target2 state -> state`
- `apply-gate-kq : matrix targets state -> state`  (general fallback; correctness
  reference for the specialized kernels)

Implementation style: build a fresh mutable vector inside the function, fill it, freeze
with `vector->immutable-vector`, wrap in a new `quantum-state`. Local, invisible
mutation; the API is pure.

Controlled gates need **no dedicated kernels**: a controlled-U on (control c, target t)
is the 2-qubit kernel with the controlled matrix, or equivalently the 1q update applied
only to index pairs where bit `c` is 1. Either is fine; pick one and test it against
the general kernel.

The old full-matrix path (`tensor product of a whole layer`) is still worth keeping as
`circuit->matrix : circuit -> Matrix` (defined for circuits without measurement) —
useful for tests (compare simulator output against explicit matrix multiplication on
small circuits), for users studying the linear algebra, and for building custom gates
from sub-circuits.

### 4.3 Standard gate library (`gates.rkt`)

Constants (0-parameter gates), each a `gate` struct:

| Group | Gates |
|---|---|
| Pauli | `X`, `Y`, `Z`, `ID` |
| Hadamard/phase | `H`, `S`, `S†` (`Sdg`), `T`, `Tdg` |
| Rotations | `(RX θ)`, `(RY θ)`, `(RZ θ)`, `(P θ)` (phase), `(U θ φ λ)` |
| Two-qubit | `CX`, `CY`, `CZ`, `CH`, `SWAP`, `(CP θ)`, `(CRX θ)` etc. |
| Three-qubit | `CCX` (Toffoli), `CSWAP` (Fredkin) |

Constructors for extensibility:

```racket
(matrix->gate name mat)             ; custom gate from any unitary 2^k×2^k matrix
                                    ; (validates unitarity up to tolerance, error if not)
(controlled g)                      ; gate -> gate with one more control qubit
(gate-inverse g)                    ; conjugate transpose; renames e.g. 'rx -> 'rx†
(circuit->gate name circ)           ; sub-circuit (no measurements) as a reusable gate
```

QFT is provided as a *circuit constructor* `(qft n)` / `(inverse-qft n)` built from
H and controlled-phase gates (not as a dense matrix), mirroring how Qiskit ships it.
Keep `fourier-matrix`/`inverse-fourier-matrix` in `linalg.rkt` as the test oracle for it.

### 4.4 Circuit construction API (`circuit.rkt`)

**Preserve the current `make-circuit` shape.** A circuit is a list of layers; the
constructor and the calling convention stay what they are today:

```racket
(make-circuit layers                    ; the layer list, as today
              #:qubits [n #f]           ; inferred from layers when omitted
              #:clbits [m 0])

;; A circuit value is applicable, exactly like today's make-circuit result:
((make-circuit (list (list H I) CX)) (qubits 2))   ; -> quantum-state
;; (Applying a circuit that contains measure/when-bit is an error — use run-shot.)
```

Each **layer** is one of:

```racket
;; 1. A positional list of 1-qubit gates, one entry per qubit — today's idiom:
(list H I I)                  ; H on qubit 0; I is the identity placeholder
                              ; (a bare symbol-free gate value, no width needed)

;; 2. A bare gate — applies to qubits 0..arity-1, preserving today's
;;    (make-circuit (list X H (Rx 30))) for 1-qubit circuits and bare CX
;;    as a whole layer in 2-qubit circuits:
CX

;; 3. A gate placed at explicit qubit indices — replaces gate-matrix + cnot-f:
(at CX 0 5)                   ; CNOT, control 0, target 5, in any register width
(at CCX 0 1 2)
(at (Rx theta) 3)

;; 4. Measurement — measures qubits into classical bits (default clbit = qubit index):
(measure 0 1)                 ; qubits 0,1 -> clbits 0,1
(measure [0 2])               ; qubit 0 -> clbit 2 (bracket pairs when they differ)

;; 5. Classical conditioning — the teleportation enabler:
(when-bit 1 1 (at X 2))       ; apply X on qubit 2 iff clbit 1 = 1
```

`at`, `measure`, and `when-bit` are plain functions returning layer-item structs
(§4.1) — no macros. Because layers are plain lists, composition stays what it is
today: `append` circuits' layers, `make-list n H` for a row of Hadamards,
`for/list` to generate parameterized sweeps. Additionally provide as conveniences:

```racket
(circuit-layers c)                      ; accessor — layers are inspectable data
(circuit-append c1 c2)                  ; sequential composition (same widths)
(circuit-repeat c n)
(circuit-inverse c)                     ; reverse layers + invert gates (no measures)
```

**Do not** add a builder-chain API (`qc-h`, threading helpers) or a new macro DSL —
that is how the two-dialect problem started. The layer list is the one dialect;
plain functions over plain data.

Validation at construction time (`make-circuit` checks the whole layer list):
qubit/clbit indices in range, positional layer length = register width, arity
matches gate, no duplicate qubits in one `at`. Fail fast with clear error messages
(`raise-argument-error` style).

### 4.5 Execution and measurement (`simulator.rkt`, `measurement.rkt`)

The engine runs one **shot** by walking the instruction list:

```racket
;; run-state: for circuits WITHOUT measurement — returns final quantum-state.
;; This is what circuit application ((circ input) via prop:procedure) calls.
(run-state circ [initial-state])

;; run-shot: full semantics. Threads (quantum-state, classical-bits) through
;; the layer list:
;;   gate / at    -> apply kernel
;;   measure      -> sample outcome for those qubits from |amp|², COLLAPSE the
;;                   state (zero out inconsistent amplitudes, renormalize),
;;                   record bits into the classical register (immutable update)
;;   when-bit     -> execute inner item iff classical bit matches
;; Returns (values final-state classical-bits).
(run-shot circ [initial-state] #:rng [rng])

;; counts: KEEPS ITS CURRENT MEANING — takes a quantum-state, samples all
;; qubits per shot (no collapse across shots needed since the state is reused).
;; Returns an immutable hash: bit-string -> count. Deterministic with #:seed.
(counts state #:shots [shots 1024] #:seed [seed #f])
;; so today's call sites keep working:  (counts (circuit1 (qubits 2)))

;; run-shots: for circuits WITH measurement/conditioning — repeats run-shot,
;; tallies the CLASSICAL register. Same hash shape as counts.
(run-shots circ [initial-state] #:shots [shots 1024] #:seed [seed #f])

;; Bit-string keys in both are printed MSB-first, i.e. qubit/clbit 0 is the
;; RIGHTMOST character — exactly Qiskit's convention.

;; probabilities: exact distribution of a state without sampling.
(probabilities state)
```

Notes:
- Mid-circuit measurement + collapse + classical conditioning gives teleportation
  directly, and is the honest semantics (per-shot execution), matching Qiskit's
  dynamic-circuit model.
- Sampling: compute cumulative probabilities of the measured qubits'
  marginal distribution, roll `(random rng)` — a real — and select. This fixes
  defect #1.
- RNG: accept an optional `pseudo-random-generator` / seed for reproducibility
  instead of mutating the global seed.
- `counts` accumulates with `hash-update` on an immutable hash via `for/fold`.

### 4.6 Visualization (`plot.rkt`, `draw-text.rkt`, `draw-pict.rkt`)

- `(plot-histogram counts)` — discrete histogram of a counts hash, labels are the
  bit-strings, sorted; also `(plot-state-probabilities state)` for a state's exact
  distribution. Built on `plot`. Return the plot object so it works in DrRacket and
  can be saved with `plot-file` conventions.
- `(circuit->text circ)` — ASCII renderer. Layout algorithm: assign each instruction
  to the earliest column where all its wires are free (greedy left-packing);
  draw one row per qubit + one per classical bit; multi-qubit gates draw control dots
  `●`, targets `⊕`/boxed names, vertical connectors `│`; measurement draws `M` with a
  double-line drop to the classical wire. Monospace, printable in any terminal.
- `(circuit->pict circ)` — Phase 5: same column layout, rendered with `pict`
  (boxes, circles, lines). Because it's a `pict`, it composes in DrRacket, Scribble
  docs, and can be exported to PNG/SVG via `racket/draw` — all standard libs.
- **Bloch sphere diagrams** (`bloch.rkt`, post-plan extension): a qubit of any
  n-qubit state reduces (partial trace) to a 2×2 density matrix whose Pauli
  expectations give the Bloch vector — `(qubit-density-matrix state q)`,
  `(bloch-vector state q)` returning `(list x y z)`. Rendering:
  `(bloch-pict state [q] #:size s)` draws one qubit (sphere outline, dashed
  equator, axes, red vector arrow; a center dot when |r| ≈ 0, i.e. maximally
  entangled/mixed); `(bloch-pict* state)` draws all qubits side by side.
  Circuit usage is by application: `(bloch-pict (circ (qubits n)) q)`.
  Pure `pict`/`racket/draw`, same composability as `circuit->pict`.

---

## 5. Phased Implementation

Each phase ends with all tests passing (`raco test tests/`) and compiling clean.
Do not start a phase until the previous one is green. Phases are sized so each is
comfortable in one focused session.

### Phase 1 — Package skeleton + math core
- Create `info.rkt`, directory layout, empty `main.rkt`.
- `linalg.rkt`: `tensor-product` (pure, `for/fold`, no `set!` — replaces the old
  `tensor*`), `matrix-~=` tolerant comparison, unitarity check, `fourier-matrix`,
  `inverse-fourier-matrix`, bits↔index conversions (little-endian, one canonical
  set of functions: `index->bits`, `bits->index`, `index->bit-string`).
- `state.rkt`: `quantum-state` struct, `(zero-state n)`, `(basis-state n k)`,
  `(state-probability state k)`, `(qubit-probability state q v)` (marginal
  probability that qubit `q` measures as `v`), `(state-normalized? state)`,
  `state-~=`.
- Tests: tensor product against hand-computed 2- and 3-qubit cases; Fourier matrix
  unitarity; bit conversion round-trips.
- **Acceptance**: `raco test` green; `raco make` clean.

### Phase 2 — Gates + circuit IR
- `gates.rkt`: full table from §4.3 with matrices; `matrix->gate` with unitarity
  validation; `gate-inverse`; `controlled`.
- `circuit.rkt`: structs from §4.1; `make-circuit` with all layer shapes from §4.4
  except `measure`/`when-bit`; `at`; layer validation; `circuit-append`,
  `circuit-repeat`, `circuit-inverse`, `circuit->gate`, `(qft n)`,
  `(inverse-qft n)`; `prop:procedure` application.
- Tests: each gate matrix vs. known values (e.g. HZH = X, S² = Z, T² = S);
  `controlled X` equals `CX`; `qc-inverse` of a random gate sequence composed with
  itself is identity (via `circuit->matrix` in Phase 3, so here just structural
  tests + gate-level inverse tests); builder validation errors.
- **Acceptance**: green tests; circuits for Bell pair and GHZ construct without error.

### Phase 3 — Simulator
- `simulator.rkt`: kernels `apply-gate-1q/2q/kq` (§4.2); `run-state`;
  `circuit->matrix` (measurement-free circuits) as the test oracle.
- Cross-validate: for randomized small circuits (n ≤ 5, depth ≤ 20, gates drawn from
  the standard library), `run-state` must match `circuit->matrix` × initial state to
  1e-9. This test is the heart of the library's credibility — be thorough.
- Property tests: norm preserved after every gate; H twice = identity; Bell state
  amplitudes = (1/√2, 0, 0, 1/√2); QFT on basis states matches `fourier-matrix`.
- Benchmark sanity (not a test, a script note): 20-qubit, depth-30 circuit should
  run `run-state` in seconds, not minutes.
- **Acceptance**: green tests including the cross-validation suite.

### Phase 4 — Measurement, classical control, examples
- `measurement.rkt`: sampling with real-valued roll, partial measurement with
  collapse + renormalize, `run-shot`, `counts` (state-based, current meaning,
  immutable + seedable), `run-shots` (circuit-based), `probabilities`.
- `circuit.rkt`: add `measure` and `when-bit` layer items and their execution
  in `run-shot`.
- Rewrite all examples against the new API: **teleportation** (the litmus test —
  measure Alice's two qubits, classically-conditioned X and Z on Bob's qubit,
  verify Bob's state equals the input state for several random inputs),
  superdense, Bernstein–Vazirani (oracle as a list of `at` layers — this replaces
  the old `gate-matrix`+`cnot-f` machinery), Deutsch–Jozsa, Grover
  (2–3 qubits), QFT demo, BB84 (now using partial measurement naturally), adiabatic.
  See Appendix A for target renderings of the key examples — they should stay this
  close to the pre-rewrite code.
- Tests: statistical tests with fixed seeds (e.g. Bell measurement gives only
  "00"/"11", roughly half each over 4096 shots with generous tolerance);
  teleportation end-to-end; collapse correctness (measuring qubit 0 of a Bell pair
  forces qubit 1).
- **Delete `qsym.rkt`, `qlang.rkt`, `bb84_simple.rkt`, `ex_*.rkt`** once replaced.
- **Acceptance**: green tests; every example runs top-to-bottom via `racket examples/x.rkt`.

### Phase 5 — Visualization
- `plot.rkt`: `plot-histogram` (sorted bit-string axis), `plot-state-probabilities`.
- `draw-text.rkt`: `circuit->text` per §4.6, including measurement drops and
  conditioned-gate markers; `(print-circuit circ)` convenience.
- `draw-pict.rkt`: `circuit->pict` sharing the column-layout code with the text
  renderer (factor layout into a common helper).
- Tests: layout column-assignment unit tests; golden-string tests for `circuit->text`
  on Bell, teleportation, and a 3-qubit GHZ; pict smoke tests (non-#f, sane width).
- **Acceptance**: teleportation circuit renders correctly in ASCII and as a pict.

### Phase 6 — Contracts, docs, polish
- Curate `main.rkt` exports with `contract-out` on the entire public API.
- `scribblings/qsym.scrbl`: reference documentation for every export + a tutorial
  chapter that walks Bell pair → teleportation → Grover.
- Rewrite `README.md` (single dialect!) and replace/retire `qsym_tutorial.md`
  in favor of the Scribble docs (keep a short markdown quickstart in README).
- Final pass: `raco test` across the package, fix any contract-violation surprises
  in examples, spell out the endianness convention prominently in docs.
- **Acceptance**: `raco setup --check-pkg-deps` clean, docs build, all green.

---

## 6. Testing Strategy (summary)

- `rackunit`, one test module per library module, all runnable via `raco test tests/`.
- Three layers of assurance:
  1. **Unit**: gate matrices, bit conversions, builders, validation errors.
  2. **Cross-validation**: fast index-arithmetic simulator vs. explicit
     `circuit->matrix` linear algebra on randomized small circuits (the oracle
     approach — the two implementations share no code paths).
  3. **Statistical/end-to-end**: seeded `counts` distributions for canonical states;
     full protocols (teleportation, BB84, Grover success probability) as executable
     specifications.
- Numerical tolerance: `1e-9` for state comparisons via a single shared `~=` helper —
  never exact `equal?` on floats.

## 7. Guidance for the Implementing Model

- Read this file fully before writing code. When this plan and convenience conflict,
  follow the plan; when the plan is silent, follow the style mandates in §1.
- Commit at each phase boundary with a message naming the phase.
- The old `qsym.rkt` is a useful reference for the math (gate matrices, QFT
  definition, `gate-matrix`'s permutation trick) but do not copy its structure;
  defects listed in §2 must not survive.
- Do not add macros beyond what §4.4 allows. Do not add third-party packages.
- Keep functions small and named for what they mean in the physics
  (`collapse-state`, `marginal-distribution`), not for how they compute it.

---

## Appendix A — Target example code (style anchor)

These renderings define how close the new API must stay to the pre-rewrite code.
If an example cannot be written roughly this way, the API is wrong, not the example.

### Superdense coding (compare `ex_1_superdense.rkt`)

Today this is four hand-copied circuits; the only structural change is that the
message bits become parameters. The layer-list shape is untouched:

```racket
(define (superdense b1 b0)
  (make-circuit (append
                 (list (list H I)
                       CX)
                 (if (= b0 1) (list (list Z I)) '())
                 (if (= b1 1) (list (list X I)) '())
                 (list CX
                       (list H I)))))

(define input (qubits 2))
(counts ((superdense 0 1) input))                    ;; call sites unchanged
(plot-histogram (counts ((superdense 0 1) input)))
```

### Bernstein–Vazirani (compare `ex_2_vazirani_bernstein.rkt`)

`(at CX 0 5)` replaces `gate-matrix` + `cnot-f`; everything else keeps its shape,
including `make-list` for the Hadamard rows:

```racket
(define (oracle secret)                  ;; secret: bit list, qubit i ↔ bit i
  (let ([n (length secret)])
    (for/list ([b secret] [i (in-naturals)]
               #:when (= b 1))
      (at CX i n))))

(define cirq
  (make-circuit (append
                 (list (list I I I I I X)
                       (make-list 6 H))
                 (oracle '(1 1 0 0 1))
                 (list (make-list 6 H)))))

(plot-histogram (counts (cirq (qubits 6)) #:shots 2000))
```

### Adiabatic sweep (compare `ex_3_adiabatic.rkt`)

Unchanged in shape — `Rx`/`Rz` now return gate structs instead of bare matrices,
which is invisible at the call site:

```racket
(define (adiabatic-gates angle)
  (flatten
   (for/list ([i (in-range 0 1 0.001)])
     (list (Rx (* angle (- 1 i)))
           (Rz (* angle i))))))

(define a-circuit (make-circuit (append (list X H) (adiabatic-gates 30))))
(plot-histogram (counts (a-circuit q0)))
```

### Teleportation (new — impossible in the current library)

This is the complete target rendering of `examples/teleportation.rkt` — a simple,
runnable walkthrough in the same layer-list style, using the three new layer items.
Phase 4 should produce essentially this file:

```racket
#lang racket

;; Quantum teleportation: Alice sends the state of qubit 0 to Bob's qubit 2
;; using a shared Bell pair (qubits 1,2) and two classical bits.
;;
;;  q0 (payload) ──────●──[H]──[M]═══════════╗       (clbit 0)
;;  q1 (Alice)  ──[H]──●──⊕────[M]══╗        ║       (clbit 1)
;;  q2 (Bob)    ───────⊕────────────[X if 1]─[Z if 1]─── payload appears here

(require qsym)

(define teleport
  (make-circuit (list (list I H I)          ;; Bell pair between Alice & Bob:
                      (at CX 1 2)           ;;   qubits 1,2 -> (|00>+|11>)/sqrt(2)
                      (at CX 0 1)           ;; Alice entangles payload with her half
                      (list H I I)
                      (measure 0 1)         ;; Alice measures -> clbits 0,1
                      (when-bit 1 1 (at X 2))  ;; Bob's corrections, driven by
                      (when-bit 0 1 (at Z 2))) ;; Alice's classical bits
                #:clbits 2))

(print-circuit teleport)

;; The payload: an arbitrary single-qubit state on qubit 0.
(define payload (gRx (/ pi 3) q0))

;; One shot: qubits 1,2 start in |00> and become the Bell pair inside the circuit.
(define-values (final-state cbits) (run-shot teleport (t* payload (qubits 2))))

(displayln (format "Alice's classical bits: ~a" cbits))

;; Verify: Bob's qubit (qubit 2) now has the payload's probabilities,
;; regardless of which of the four (random) classical outcomes occurred.
(displayln (format "payload P(|1>):     ~a" (state-probability payload 1)))
(displayln (format "Bob qubit 2 P(|1>): ~a" (qubit-probability final-state 2 1)))

;; Statistics over many shots: measuring Bob's qubit after teleportation
;; reproduces the payload's distribution.
(define teleport+check
  (circuit-append teleport
                  (make-circuit (list (measure [2 0])) #:qubits 3 #:clbits 2)))

(plot-histogram (run-shots teleport+check (t* payload (qubits 2))
                           #:shots 2048 #:seed 42))
;; clbit 0 is ~75% zero / ~25% one — exactly cos²(π/6) / sin²(π/6),
;; the Rx(π/3) payload, now living on Bob's qubit.
```

`(qubit-probability state q v)` — the probability that measuring qubit `q` alone
yields `v` (marginal over the other qubits) — is part of `state.rkt`'s public API;
this example is why.

State-level helpers used by BB84 today (`q0`, `qubits`, `t*`, `gX`, `gH`, `gRx`...)
remain in the public API so per-qubit protocol code keeps its current style.
