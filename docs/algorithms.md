# qsym — Algorithm Notes

Each section records an algorithm choice or refactor: what changed, why, and the
complexity impact. Add a new section whenever a better technique is introduced.

---

## 1. Tensor (Kronecker) Product — `private/linalg.rkt`

### Old implementation (`qsym.rkt: tensor*`)

The legacy code converted matrices to nested lists, assembled output rows by
hand, then converted back:

```
mat->list  : Matrix × Matrix → nested list
  For every element x of m1 (r1×c1), matrix-map over m2 scaling each y → x*y,
  then convert that scaled matrix to a nested list.
  Result: r1×c1 outer list, each cell holding an r2×c2 inner list.

list->mat  : nested structure → flat row list
  For each of r1 outer rows:
    For each column index i (0 .. c2-1):
      (list-ref block i)                   ; O(i) list scan each call
      (set! row-line (append row-line …))  ; O(|row-line|) copy each append
    (set! rows (append rows …))            ; O(|rows|) copy each append

list*->matrix : flat list of rows → Matrix
```

**Dominant cost — `list->mat`:**
- `list-ref` on a list is O(i), called once per (block, column) pair → O(c2) average per block.
- `append row-line` copies the accumulator on every call → O(c1·c2) work per row.
- Combined per output row: O(c1·c2²).
- Over all r1·r2 output rows: **O(r1·r2·c1·c2²)**.
- Additional O(r1·r2·c1·c2) allocation for the intermediate nested list structure.
- Three representation round-trips: matrix → nested list → flat list → matrix.
- `set!` on `rows` and `row-line` is not local to a hot path; mutable state
  threads through the entire construction.

### New implementation (`private/linalg.rkt: tensor-product`)

The Kronecker product element formula is applied directly via `build-matrix`:

```
A⊗B element at (i, j) = A[i / r2, j / c2]  ×  B[i % r2, j % c2]
```

```racket
(define (tensor-product m1 m2)
  (let ([r2 (matrix-num-rows m2)]
        [c2 (matrix-num-cols m2)])
    (build-matrix (* (matrix-num-rows m1) r2)
                  (* (matrix-num-cols m1) c2)
                  (λ (i j)
                    (* (matrix-ref m1 (quotient  i r2) (quotient  j c2))
                       (matrix-ref m2 (remainder i r2) (remainder j c2)))))))
```

**Cost:** `build-matrix` allocates one flat backing array of size (r1·r2)×(c1·c2)
and fills it in a single pass. Each cell requires two integer divisions and two
O(1) array reads.  Total: **O(r1·r2·c1·c2)** — the information-theoretic minimum
(every output element must be written exactly once).

### Comparison

| | Old `tensor*` | New `tensor-product` |
|---|---|---|
| Time complexity | O(r1·r2·c1·c2²) | O(r1·r2·c1·c2) |
| Intermediate allocations | O(r1·r2·c1·c2) list nodes | 0 |
| Representation round-trips | 3 (matrix→list→list→matrix) | 0 |
| Mutable state | `set!` on `rows`, `row-line` | none |
| Technique | List assembly + matrix conversion | `build-matrix` with index arithmetic |

### Impact on circuit simulation

Gate matrices in an n-qubit circuit are at most 2^n × 2^n. When the legacy
`tensor*` is called repeatedly to build a layer matrix (Plan.md §2 defect #2),
the c2² factor compounds: assembling a 3-qubit 8×8 product via two 2×2⊗2×2
steps costs O(4·4·4·16) = O(1024) with the old code versus O(4·4·4·4) = O(256)
with the new one. At 20 qubits the difference becomes O(4^20 · 2²) vs O(4^20) —
a 4× constant that matters when the base is already 10^12 operations.
(The Phase 3 simulator avoids building full 2^n × 2^n layer matrices entirely,
but `tensor-product` is still used to construct gate matrices from sub-circuits
and for the `circuit->matrix` oracle in tests.)
