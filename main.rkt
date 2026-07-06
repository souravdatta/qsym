#lang racket/base

;; qsym public API — populated across implementation phases.

(require "private/linalg.rkt"
         "private/state.rkt"
         "private/gates.rkt"
         "private/circuit.rkt")

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
 t*)
