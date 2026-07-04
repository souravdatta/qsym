#lang racket/base

;; qsym public API — populated across implementation phases.

(require "private/linalg.rkt"
         "private/state.rkt")

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
 q0)
