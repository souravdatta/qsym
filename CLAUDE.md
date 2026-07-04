# CLAUDE.md — qsym

qsym is a quantum computing **simulation** library in Racket. Scope: state-vector
simulation, measurement (including partial/mid-circuit + classical conditioning),
plotting, and circuit diagram drawing. Nothing hardware-related, no noise models.

## Start here

- **`Plan.md` is the authoritative design document.** Before implementing or changing
  anything substantial, read it. It defines the architecture, the module layout, the
  public API, six implementation phases with acceptance criteria, and a list of known
  defects in the legacy code that must not be reintroduced.
- If the repo still contains `qsym.rkt` / `qlang.rkt` / `ex_*.rkt` / `bb84_simple.rkt`
  at the top level, those are **legacy** (pre-plan) files. Use `qsym.rkt` only as a
  math reference; `qlang.rkt` is a second dialect being removed entirely. They are
  deleted at the end of Plan.md Phase 4 — do not extend them.

## Hard rules

- **One circuit dialect only**: the immutable layer-list circuit defined in
  Plan.md §4 — the current raw style, upgraded, NOT a builder-chain or macro DSL.
  Plan.md Appendix A shows target example code; new API must keep examples that
  close to the pre-rewrite style. Never introduce a second dialect.
- **Racket standard distribution libraries only** (`math`, `plot`, `pict`,
  `racket/draw`, `rackunit`, `racket/contract`, `scribble`). No third-party packages.
- **Immutability**: no `set!`, no mutable hashes/vectors in public code paths.
  Local mutation inside a function (build vector → freeze → return) is acceptable
  only in simulator hot paths and must be invisible to callers.
- **Endianness is little-endian, Qiskit-compatible**: qubit 0 is the least-significant
  bit of a basis-state index; bit strings print MSB-first (clbit 0 rightmost).
  This holds everywhere — state indexing, measurement output, drawing, plots.
- Every public function gets a `racket/contract` contract and a short doc comment.
  Public exports are curated in `main.rkt` via `contract-out`.

## Style

- SICP/Scheme flavor: small pure functions, plain `#:transparent` structs and lists,
  `for/fold` and explicit recursion. **Prefer simple, longer code over clever, dense
  code.**
- `#lang racket/base` with explicit requires in library modules; `#lang racket` is
  fine in `examples/`.
- Name functions for the physics, not the mechanics: `collapse-state`,
  `marginal-distribution` — not `zero-and-rescale`.
- Never compare floats with `equal?`; use the shared `~=` helpers (tolerance 1e-9).
- Reproducibility via an explicit RNG/seed parameter (e.g. `counts #:seed`), never
  by mutating the global `random-seed`.

## Algorithm documentation

Whenever you refactor an algorithm, replace a data structure, or use a language
feature that changes asymptotic or practical performance, add a new section to
`docs/algorithms.md`.  Each section must include:
- The old approach (code sketch + complexity).
- The new approach (code sketch + complexity).
- A side-by-side comparison table.
- The practical impact (why it matters for this library's workloads).

Do this in the same commit as the code change.

## Commands

```sh
raco test tests/            # run the full test suite (must be green before commit)
raco make main.rkt          # compile check
racket examples/<name>.rkt  # run an example end-to-end
raco setup --check-pkg-deps # dependency hygiene (Phase 6+)
```

## Testing expectations

Three layers (see Plan.md §6): unit tests per module; **cross-validation** of the
fast index-arithmetic simulator against the independent `circuit->matrix` linear
algebra oracle on randomized small circuits; seeded statistical/end-to-end protocol
tests (teleportation, BB84, Grover). Any change to simulator kernels or measurement
must keep the cross-validation suite green — it is the library's credibility.

## Workflow

- Implement in the phase order given in Plan.md; finish a phase (tests green,
  compiles clean) before starting the next. Commit at phase boundaries with the
  phase name in the message.
- New gates go in `private/gates.rkt` with a matrix test against known identities;
  new algorithms go in `examples/` built purely on the public API.
- When Plan.md and convenience conflict, follow Plan.md. When Plan.md is silent,
  follow the style rules above. If a genuine design change is needed, update
  Plan.md in the same commit so the two never diverge.
