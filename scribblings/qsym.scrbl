#lang scribble/manual

@(require (for-label qsym
                     racket/base
                     math/matrix
                     pict))

@title{qsym — Quantum State-Vector Simulation}
@author{pvsouravdatta}

@defmodule[qsym]

@bold{qsym} is a quantum state-vector simulation library for Racket.
It covers n-qubit simulation, full and partial measurement with classical
conditioning, circuit drawing, and histogram plots.
There are no hardware backends and no noise models.

@bold{Endianness:} All of qsym uses @bold{little-endian, Qiskit-compatible}
ordering.  Qubit 0 is the least-significant bit of a basis-state index.
Bit strings are printed MSB-first so qubit 0 appears at the rightmost
position (e.g., the Bell state gives outcomes @racket["00"] and @racket["11"],
where the rightmost character is qubit 0).

@table-of-contents[]

@; ─────────────────────────────────────────────────────────────────
@section{Tutorial}
@; ─────────────────────────────────────────────────────────────────

@subsection{Bell pair}

@racketblock[
(require qsym)

(define bell
  (make-circuit (list (list H ID) (at CX 0 1)) #:qubits 2))

(define state (bell (qubits 2)))
(displayln (counts state #:shots 1024 #:seed 1))
]

@racket[make-circuit] accepts a flat list of @italic{layer items}.
A positional list @racket[(list H ID)] applies @racket[H] to qubit 0 and
@racket[ID] to qubit 1.  @racket[(at CX 0 1)] places the 2-qubit CNOT gate
with control qubit 0 and target qubit 1.

Calling the circuit struct on a state runs the circuit:
@racketblock[(bell (qubits 2))]
is equivalent to @racket[(run-state bell (qubits 2))].

@subsection{Quantum teleportation}

Teleportation requires mid-circuit measurement and classically-conditioned
gates — both first-class in qsym.

@racketblock[
(define teleport
  (make-circuit
   (list (list ID H ID)
         (at CX 1 2)
         (at CX 0 1)
         (list H ID ID)
         (measure 0 1)
         (when-bit 1 1 (at X 2))
         (when-bit 0 1 (at Z 2)))
   #:clbits 2))

(define payload (gRx (/ pi 3) q0))
(define initial (t* payload (qubits 2)))
(define-values (final cbits) (run-shot teleport initial))

(displayln (format "Alice's bits: ~a" (vector->list cbits)))
(displayln (format "Bob P(|1>): ~a" (qubit-probability final 2 1)))
]

@racket[measure] stores outcomes in the classical register.
@racket[when-bit] reads a classical bit and applies its gate only if the
bit equals the given value.  @racket[run-shot] threads the state and
classical register through the circuit, returning both at the end.

@subsection{Grover's algorithm (2 qubits)}

@racketblock[
(define grover-2q
  (make-circuit
   (list (list H H)
         CZ
         (list H H) (list X X) CZ (list X X) (list H H))
   #:qubits 2))

(define result (grover-2q (qubits 2)))
(state-probability result 3)   ; => ≈ 1.0  (|11⟩ amplified)
]

For n = 2 with oracle targeting @litchar{|11⟩}, a single Grover iteration
achieves probability 1.  The diffusion operator is
@racket[H⊗H · X⊗X · CZ · X⊗X · H⊗H].

@subsection{Circuit drawing}

@racketblock[
(print-circuit grover-2q)
; q0 : ─[H]──●──[H]──[X]──●──[X]──[H]─
; q1 : ─[H]──●──[H]──[X]──●──[X]──[H]─

(define p (circuit->pict grover-2q))   ; returns a pict
]

@; ─────────────────────────────────────────────────────────────────
@section{Linear Algebra}
@; ─────────────────────────────────────────────────────────────────

@defproc[(tensor-product [m1 matrix?] [m2 matrix?]) matrix?]{
  Kronecker (tensor) product A⊗B.
}

@defproc[(matrix-~= [m1 matrix?] [m2 matrix?] [tol real? 1e-9]) boolean?]{
  Element-wise tolerant comparison: @racket[#t] iff every element differs
  by less than @racket[tol] in magnitude.
}

@defproc[(matrix-adjoint [m matrix?]) matrix?]{
  Conjugate transpose (Hermitian adjoint) of @racket[m].
}

@defproc[(matrix-unitary? [m matrix?] [tol real? 1e-9]) boolean?]{
  @racket[#t] iff @racket[m†m ≈ I] within @racket[tol].
}

@defproc[(fourier-matrix [N exact-positive-integer?]) matrix?]{
  The N×N DFT matrix: @math{F_{jk} = ω^{jk} / √N} where @math{ω = e^{2πi/N}}.
}

@defproc[(inverse-fourier-matrix [N exact-positive-integer?]) matrix?]{
  The N×N inverse DFT matrix (conjugate of @racket[fourier-matrix]).
}

@defproc[(index->bits [k exact-nonneg-integer?] [n exact-positive-integer?])
         (listof (integer-in 0 1))]{
  Decompose @racket[k] into @racket[n] bits, little-endian (bit 0 first).
}

@defproc[(bits->index [bits (listof (integer-in 0 1))]) exact-nonneg-integer?]{
  Reconstruct an index from a little-endian bit list.
}

@defproc[(index->bit-string [n exact-positive-integer?] [k exact-nonneg-integer?])
         string?]{
  Format @racket[k] as an @racket[n]-character bit string, MSB-first
  (qubit 0 rightmost, Qiskit convention).
}

@; ─────────────────────────────────────────────────────────────────
@section{Quantum States}
@; ─────────────────────────────────────────────────────────────────

@defstruct[quantum-state ([num-qubits exact-positive-integer?]
                          [amplitudes (vectorof complex?)])]{
  An n-qubit pure state: an immutable vector of @math{2^n} complex amplitudes.
  Index @racket[k] corresponds to the basis state whose qubit values are given
  by the little-endian bits of @racket[k].
}

@defproc[(zero-state [n exact-positive-integer?]) quantum-state?]{
  The all-zeros state @litchar{|0…0⟩}: amplitude 1 at index 0.
}

@defproc[(basis-state [n exact-positive-integer?] [k exact-nonneg-integer?]) quantum-state?]{
  The @racket[k]-th computational basis state: amplitude 1 at index @racket[k].
}

@defproc[(qubits [n exact-positive-integer?]) quantum-state?]{
  Alias for @racket[zero-state]: the n-qubit all-zero state.
}

@defthing[q0 quantum-state?]{
  The single-qubit zero state @litchar{|0⟩}.  Equivalent to @racket[(zero-state 1)].
}

@defproc[(state-probability [state quantum-state?] [k exact-nonneg-integer?]) real?]{
  Probability of measuring the basis state with index @racket[k]: @math{|ψ_k|²}.
}

@defproc[(qubit-probability [state quantum-state?] [q exact-nonneg-integer?]
                             [v (integer-in 0 1)]) real?]{
  Marginal probability that qubit @racket[q] alone measures as @racket[v].
}

@defproc[(state-normalized? [state quantum-state?]) boolean?]{
  @racket[#t] iff the state vector has unit norm (within @racket[1e-9]).
}

@defproc[(state-~= [s1 quantum-state?] [s2 quantum-state?]) boolean?]{
  @racket[#t] iff every amplitude differs by less than @racket[1e-9].
}

@defproc[(t* [s1 quantum-state?] [s2 quantum-state?]) quantum-state?]{
  Tensor product of two states: the combined system.
  @racket[(t* q0 q0)] is the 2-qubit state @litchar{|00⟩}.
}

@; ─────────────────────────────────────────────────────────────────
@section{Gates}
@; ─────────────────────────────────────────────────────────────────

@defstruct[gate ([name symbol?] [arity exact-positive-integer?]
                 [matrix matrix?] [params list?])]{
  A quantum gate: a name, qubit count, unitary matrix, and optional
  parameter list (e.g., rotation angle — used for display and inversion).
}

@subsection{1-qubit gate constants}

@deftogether[(
  @defthing[ID gate?]
  @defthing[X gate?]
  @defthing[Y gate?]
  @defthing[Z gate?]
  @defthing[H gate?]
  @defthing[S gate?]
  @defthing[Sdg gate?]
  @defthing[T gate?]
  @defthing[Tdg gate?]
)]{
  Standard 1-qubit gates: identity, Pauli X/Y/Z, Hadamard,
  S (phase), S†, T (π/8 gate), T†.
}

@subsection{1-qubit parametric constructors}

@defproc[(RX [theta real?]) gate?]{Rotation around X axis by @racket[theta] radians.}
@defproc[(RY [theta real?]) gate?]{Rotation around Y axis by @racket[theta] radians.}
@defproc[(RZ [theta real?]) gate?]{Rotation around Z axis by @racket[theta] radians.}
@defproc[(P  [theta real?]) gate?]{Phase gate: @math{diag(1, e^{iθ})}.}
@defproc[(U  [theta real?] [phi real?] [lam real?]) gate?]{
  General single-qubit unitary @math{U(θ, φ, λ)}.
}

@subsection{2-qubit gate constants}

@deftogether[(
  @defthing[CX gate?]
  @defthing[CY gate?]
  @defthing[CZ gate?]
  @defthing[CH gate?]
  @defthing[SWAP gate?]
)]{
  Controlled-X (CNOT), controlled-Y, controlled-Z, controlled-H, and SWAP.
  Convention: in @racket[(at CX ctrl tgt)], the first qubit index is the control.
}

@defproc[(CP  [theta real?]) gate?]{Controlled-phase gate.}
@defproc[(CRX [theta real?]) gate?]{Controlled-Rx gate.}

@subsection{3-qubit gate constants}

@deftogether[(
  @defthing[CCX gate?]
  @defthing[CSWAP gate?]
)]{
  Toffoli (CCX) and Fredkin (CSWAP).
  @racket[(at CCX ctrl1 ctrl2 tgt)] — controls are the first two qubit arguments.
}

@subsection{Gate constructors}

@defproc[(matrix->gate [name symbol?] [mat matrix?]) gate?]{
  Wrap a unitary matrix as a named gate.  Raises an error if @racket[mat]
  is not unitary or its size is not a power of 2.
}

@defproc[(gate-inverse [g gate?]) gate?]{
  Conjugate transpose of @racket[g].  The new gate's name has @litchar{†} appended.
}

@defproc[(controlled [g gate?]) gate?]{
  Add one control qubit (local qubit 0 in @racket[at]) to gate @racket[g].
  @racket[(controlled X)] equals @racket[CX].
}

@; ─────────────────────────────────────────────────────────────────
@section{Circuit IR}
@; ─────────────────────────────────────────────────────────────────

@subsection{Layer items}

@defstruct[gate-at ([gate gate?] [qubits (listof exact-nonneg-integer?)])]{
  A gate placed at explicit qubit indices.  Constructed with @racket[at].
}

@defstruct[measure-at ([qubits (listof exact-nonneg-integer?)]
                       [clbits (listof exact-nonneg-integer?)])]{
  Measurement of @racket[qubits], outcomes stored in @racket[clbits].
  Constructed with @racket[measure].
}

@defstruct[when-bit* ([clbit exact-nonneg-integer?]
                      [value (integer-in 0 1)]
                      [item any/c])]{
  Apply @racket[item] only when classical bit @racket[clbit] equals @racket[value].
  Constructed with @racket[when-bit].
}

@subsection{Layer item constructors}

@defproc[(at [g gate?] [q exact-nonneg-integer?] ...) gate-at?]{
  Place @racket[g] at the listed qubit indices.
  The number of indices must equal @racket[(gate-arity g)].
  The first index is always the control for controlled gates.
}

@defproc[(measure [arg (or/c exact-nonneg-integer?
                             (list/c exact-nonneg-integer? exact-nonneg-integer?))]
                  ...) measure-at?]{
  Create a measurement item.  Each argument is either a qubit index
  (stores result in the same-numbered classical bit) or a @racket[(list q c)]
  pair (qubit @racket[q] → classical bit @racket[c]).
}

@defproc[(when-bit [clbit exact-nonneg-integer?]
                   [value (integer-in 0 1)]
                   [item any/c]) when-bit*?]{
  Classically-conditioned item: apply @racket[item] when
  @racket[clbit] equals @racket[value] in the current shot.
}

@subsection{Circuit struct and builder}

@defstruct[circuit ([num-qubits exact-positive-integer?]
                    [num-clbits exact-nonneg-integer?]
                    [layers list?])]{
  A circuit: qubit count, classical-bit count, and flat ordered list of
  layer items.  Calling a @racket[circuit] as a procedure applies it to a
  state: @racket[(circ state)] is @racket[(run-state circ state)].
}

@defproc[(make-circuit [layers list?]
                       [#:qubits n (or/c #f exact-positive-integer?) #f]
                       [#:clbits m exact-nonneg-integer? 0]) circuit?]{
  Build a circuit from a list of layer items.  @racket[#:qubits] defaults
  to the minimum needed to accommodate all items.  @racket[#:clbits] defaults
  to the minimum needed for all @racket[measure] and @racket[when-bit] items.
}

@subsection{Circuit combinators}

@defproc[(circuit-append [c1 circuit?] [c2 circuit?]) circuit?]{
  Concatenate two circuits.  Qubit counts must be equal.
}

@defproc[(circuit-repeat [c circuit?] [n exact-positive-integer?]) circuit?]{
  Repeat a circuit @racket[n] times.
}

@defproc[(circuit-inverse [c circuit?]) circuit?]{
  Reverse all layers and invert each gate.  Measurement layers are
  kept in their reversed positions.
}

@defproc[(circuit->gate [name symbol?] [c circuit?]) gate?]{
  Convert a measurement-free circuit to a single gate by computing its
  full unitary matrix.  Raises an error if the circuit contains measurements.
}

@defproc[(circuit->matrix [c circuit?]) matrix?]{
  Return the full @math{2^n × 2^n} unitary matrix of a measurement-free circuit.
  Exponential in n — suitable only for small circuits and testing.
}

@defproc[(qft [n exact-positive-integer?]) circuit?]{
  The n-qubit Quantum Fourier Transform circuit.
}

@defproc[(inverse-qft [n exact-positive-integer?]) circuit?]{
  The n-qubit inverse QFT circuit.
}

@; ─────────────────────────────────────────────────────────────────
@section{Simulator}
@; ─────────────────────────────────────────────────────────────────

@defproc[(run-state [circ circuit?] [state quantum-state?]) quantum-state?]{
  Apply a measurement-free circuit to a state using the O(2^n) index-arithmetic
  kernels.  Raises an error if the circuit contains @racket[measure] or
  @racket[when-bit] layers; use @racket[run-shot] for those.
}

@defproc[(apply-gate-kq [mat matrix?] [qs (listof exact-nonneg-integer?)]
                        [state quantum-state?]) quantum-state?]{
  Apply a k-qubit gate matrix to the listed qubit indices using
  index-arithmetic without constructing the full tensor product.
  O(2^n) per call regardless of circuit depth or qubit count.
}

@defproc[(apply-gate-1q [mat matrix?] [t exact-nonneg-integer?]
                        [state quantum-state?]) quantum-state?]{Single-qubit specialisation of @racket[apply-gate-kq].}

@defproc[(apply-gate-2q [mat matrix?] [t0 exact-nonneg-integer?]
                        [t1 exact-nonneg-integer?]
                        [state quantum-state?]) quantum-state?]{Two-qubit specialisation of @racket[apply-gate-kq].}

@subsection{Single-qubit state modifiers}

@deftogether[(
  @defthing[gX (-> quantum-state? quantum-state?)]
  @defthing[gY (-> quantum-state? quantum-state?)]
  @defthing[gZ (-> quantum-state? quantum-state?)]
  @defthing[gH (-> quantum-state? quantum-state?)]
  @defthing[gS (-> quantum-state? quantum-state?)]
  @defthing[gT (-> quantum-state? quantum-state?)]
  @defthing[gTdg (-> quantum-state? quantum-state?)]
)]{
  Apply a fixed gate to qubit 0 of a 1-qubit state.
  Example: @racket[(gH q0)] returns the @litchar{|+⟩} state.
}

@defproc[(gRx [theta real?] [state quantum-state?]) quantum-state?]{
  Apply @racket[RX(theta)] to qubit 0.
}
@defproc[(gRy [theta real?] [state quantum-state?]) quantum-state?]{
  Apply @racket[RY(theta)] to qubit 0.
}
@defproc[(gRz [theta real?] [state quantum-state?]) quantum-state?]{
  Apply @racket[RZ(theta)] to qubit 0.
}

@; ─────────────────────────────────────────────────────────────────
@section{Measurement}
@; ─────────────────────────────────────────────────────────────────

@defproc[(run-shot [circ circuit?]
                   [initial-state (or/c quantum-state? #f) #f]
                   [#:rng rng any/c (current-pseudo-random-generator)])
         (values quantum-state? vector?)]{
  Execute one shot of a circuit with full mid-circuit measurement semantics.
  Threads @racket[(state, classical-bits)] through all layers, sampling
  measurement outcomes in order.  Returns the final quantum state and an
  immutable vector of classical bit values.

  If @racket[initial-state] is @racket[#f], starts from @racket[(zero-state n)].
}

@defproc[(run-shots [circ circuit?]
                    [initial-state (or/c quantum-state? #f) #f]
                    [#:shots shots exact-positive-integer? 1024]
                    [#:seed seed (or/c #f exact-positive-integer?) #f])
         hash?]{
  Run the circuit @racket[shots] times, tallying the final classical register.
  Returns an immutable @racket[hash?] mapping bit-strings to counts.
}

@defproc[(counts [state quantum-state?]
                 [#:shots shots exact-positive-integer? 1024]
                 [#:seed seed (or/c #f exact-positive-integer?) #f])
         hash?]{
  Sample @racket[shots] outcomes from a state (no collapse, no circuit).
  Returns an immutable hash mapping bit-strings to counts.
  Reproducible when @racket[#:seed] is provided.
}

@defproc[(probabilities [state quantum-state?]) hash?]{
  Exact probability distribution: returns a hash mapping every bit-string
  with non-zero amplitude to its @math{|ψ_k|²} probability.
}

@defproc[(marginal-distribution [state quantum-state?]
                                [qs (listof exact-nonneg-integer?)])
         (vectorof real?)]{
  Joint probability distribution over qubit indices @racket[qs].
  Returns a vector of length @math{2^{|qs|}}: entry @racket[s] is
  @math{P(\text{qubit } qs_i = \text{bit}_i(s))}.
}

@defproc[(collapse-state [state quantum-state?]
                         [outcomes (listof (cons/c exact-nonneg-integer? (integer-in 0 1)))])
         quantum-state?]{
  Project and renormalize: zero out all amplitudes inconsistent with
  @racket[outcomes] (a list of @racket[(qubit . value)] pairs), then
  renormalize the remaining amplitudes to unit norm.
}

@; ─────────────────────────────────────────────────────────────────
@section{Visualization}
@; ─────────────────────────────────────────────────────────────────

@subsection{Plots}

@defproc[(plot-histogram [counts hash?] [title string? "Measurement counts"]) any]{
  Render a counts hash as a discrete probability histogram.
  Labels are bit-strings sorted lexicographically.
  Returns the plot result (works in DrRacket; save with @racket[plot-file]).
}

@defproc[(plot-state-probabilities [state quantum-state?]
                                   [title string? "State probabilities"]) any]{
  Plot the exact @math{|ψ_k|²} distribution for every basis state.
}

@subsection{ASCII circuit diagrams}

@defproc[(circuit->text [circ circuit?]) string?]{
  Render a circuit as a multi-line ASCII string.
  One row per qubit (@racket[q0], @racket[q1], …) and one per classical bit
  (@racket[c0], @racket[c1], …).

  Layout uses greedy left-packing: each item is placed in the earliest column
  where none of its wires conflict with already-placed items.

  Conventions:
  @itemlist[
    @item{Qubit wires: @litchar{───}  Classical wires: @litchar{═══}}
    @item{Control dot: @litchar{●}  XOR target: @litchar{⊕}  Gate box: @litchar{[H]}}
    @item{Measurement: @litchar{[M]} with @litchar{║} drop to classical wire}
    @item{Classical condition: @litchar{╡v} on the classical wire}
  ]
}

@defproc[(print-circuit [circ circuit?]) void?]{
  Display @racket[(circuit->text circ)] to current output.
}

@subsection{Pict-based circuit diagrams}

@defproc[(circuit->pict [circ circuit?]) pict?]{
  Render the circuit as a @racket[pict?].  The returned pict composes with
  other picts, displays in DrRacket, and can be exported to PNG or SVG via
  @racket[racket/draw].  Uses the same greedy column-layout as
  @racket[circuit->text].
}

@subsection{Layout helpers}

@defproc[(assign-columns [circ circuit?]) (listof (cons/c any/c exact-nonneg-integer?))]{
  Return an association list @racket[(item . col)] for each layer item,
  sorted in circuit order.  Both @racket[circuit->text] and
  @racket[circuit->pict] are built on this function.
}

@defproc[(item-wire-span [item any/c] [nq exact-positive-integer?])
         (values exact-nonneg-integer? exact-nonneg-integer?)]{
  Return the inclusive @racket[(lo . hi)] wire range that @racket[item]
  visually occupies.  Qubit @racket[q] maps to wire @racket[q];
  classical bit @racket[c] maps to wire @racket[(+ nq c)].
}

@defproc[(gate-label [g gate?]) string?]{
  Human-readable label for a gate: the uppercase name, with parameters
  in parentheses for parametric gates (e.g., @racket["RX(1.57)"]).
}
