#lang racket/base

;; qsym public API

(require "private/linalg.rkt"
         "private/state.rkt"
         "private/gates.rkt"
         "private/circuit.rkt"
         "private/simulator.rkt"
         "private/measurement.rkt"
         "private/plot.rkt"
         "private/draw-text.rkt"
         "private/draw-pict.rkt")

(provide
 ;; -- linalg --
 tensor-product
 matrix-~=
 matrix-adjoint
 matrix-unitary?
 fourier-matrix
 inverse-fourier-matrix
 index->bits
 bits->index
 index->bit-string
 ;; -- state --
 (struct-out quantum-state)
 zero-state
 basis-state
 state-probability
 qubit-probability
 state-normalized?
 state-~=
 qubits
 q0
 ;; -- gates --
 (struct-out gate)
 ID X Y Z H S Sdg T Tdg
 RX RY RZ P U
 CX CY CZ CH SWAP
 CP CRX
 CCX CSWAP
 matrix->gate
 gate-inverse
 controlled
 ;; -- circuit --
 (struct-out gate-at)
 (struct-out measure-at)
 (struct-out when-bit*)
 (struct-out circuit)
 at
 measure
 when-bit
 make-circuit
 circuit-layers
 circuit-append
 circuit-repeat
 circuit-inverse
 circuit->gate
 circuit->matrix
 qft
 inverse-qft
 t*
 ;; -- simulator --
 apply-gate-1q
 apply-gate-2q
 apply-gate-kq
 run-state
 gX gY gZ gH gS gT gTdg
 gRx gRy gRz
 ;; -- measurement --
 marginal-distribution
 collapse-state
 run-shot
 counts
 run-shots
 probabilities
 ;; -- plot --
 plot-histogram
 plot-state-probabilities
 ;; -- draw-text --
 circuit->text
 print-circuit
 assign-columns
 item-wire-span
 gate-label
 ;; -- draw-pict --
 circuit->pict)
