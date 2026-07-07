# qsym — Quantum State-Vector Simulation in Racket

`qsym` is a Racket library for simulating quantum circuits on a classical computer.
It covers n-qubit state-vector simulation, partial mid-circuit measurement with
classical conditioning, circuit drawing, and histogram plots.

**Convention:** qsym uses **little-endian, Qiskit-compatible** bit ordering.
Qubit 0 is the least-significant bit of a basis-state index.
Bit strings print MSB-first so qubit 0 is the rightmost character
(e.g. `"01"` means qubit 0 = 1, qubit 1 = 0).

## Quickstart

```racket
(require qsym)

;; Bell pair
(define bell
  (make-circuit (list (list H ID) (at CX 0 1)) #:qubits 2))

(define state (bell (qubits 2)))
(counts state #:shots 1024 #:seed 1)
; => #hash(("00" . 510) ("11" . 514))

(print-circuit bell)
; q0 : ─[H]───●──
; q1 : [ID]───⊕──
```

## Examples

| File | Algorithm |
|---|---|
| `examples/teleportation.rkt` | Quantum teleportation (mid-circuit measure + conditional gates) |
| `examples/grover.rkt` | Grover search (2 qubits, target \|11⟩) |
| `examples/qft.rkt` | Quantum Fourier Transform vs. DFT matrix |
| `examples/bb84.rkt` | BB84 quantum key distribution |
| `examples/superdense.rkt` | Superdense coding |
| `examples/bernstein-vazirani.rkt` | Bernstein–Vazirani algorithm |
| `examples/deutsch-jozsa.rkt` | Deutsch–Jozsa algorithm |
| `examples/adiabatic.rkt` | Adiabatic evolution (1 qubit) |

Run any example with:
```sh
racket examples/grover.rkt
```

## API summary

### States
```racket
(zero-state n)               ; |0…0⟩ with n qubits
(basis-state n k)            ; |k⟩ (amplitude 1 at index k)
(qubits n)                   ; alias for zero-state
q0                           ; the single-qubit |0⟩
(t* s1 s2)                   ; tensor product of two states
(state-probability st k)     ; |ψ_k|² for basis state k
(qubit-probability st q v)   ; marginal P(qubit q = v)
```

### Gates
```racket
;; 1-qubit constants
ID  X  Y  Z  H  S  Sdg  T  Tdg

;; Parametric
(RX theta)  (RY theta)  (RZ theta)
(P theta)   (U theta phi lam)

;; 2-qubit
CX  CY  CZ  CH  SWAP
(CP theta)  (CRX theta)

;; 3-qubit
CCX  CSWAP

;; Combinators
(controlled g)              ; add one control qubit
(gate-inverse g)            ; conjugate transpose
(matrix->gate 'name mat)    ; custom gate from unitary matrix
```

### Circuits
```racket
;; Layer items accepted by make-circuit:
;;   (list g0 g1 …)         positional: gi on qubit i (all 1-qubit)
;;   gate                   bare: gate applied to qubits 0…arity-1
;;   (at gate q0 q1 …)      explicit placement; first qubit = control
;;   (measure q …)          measure into classical register
;;   (when-bit c v item)    apply item iff classical bit c == v

(make-circuit layers #:qubits n #:clbits m)
(circuit-append c1 c2)
(circuit-repeat c n)
(circuit-inverse c)
(circuit->matrix c)    ; full 2^n × 2^n unitary (small circuits only)
(qft n)                ; Quantum Fourier Transform circuit
(inverse-qft n)
```

### Simulation
```racket
(run-state circ state)                          ; measurement-free
(run-shot  circ [state])                        ; → (values state cbits)
(run-shots circ [state] #:shots 1024 #:seed 42) ; → hash string→count
(counts    state #:shots 1024 #:seed 42)        ; no circuit, no collapse
(probabilities state)                           ; exact distribution
```

### Visualization
```racket
(print-circuit circ)           ; ASCII to stdout
(circuit->text circ)           ; ASCII as string
(circuit->pict circ)           ; pict (composable, DrRacket-friendly)
(plot-histogram counts)         ; discrete probability bar chart
(plot-state-probabilities st)   ; exact probability bar chart
(bloch-vector st q)             ; Bloch vector (x y z) of qubit q
(bloch-pict st q)               ; Bloch sphere diagram of qubit q
(bloch-pict* st)                ; one sphere per qubit, side by side
```

## Testing

```sh
raco test tests/    # 226 tests, all green
```

## Full documentation

Build and open the Scribble reference:

```sh
raco docs qsym
```
