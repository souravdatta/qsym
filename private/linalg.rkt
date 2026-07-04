#lang racket/base

;; Linear algebra helpers for quantum simulation.
;;
;; Provides Kronecker tensor product, tolerant matrix comparison, adjoint,
;; unitarity check, DFT/IDFT matrices, and little-endian bit/index conversions.
;;
;; Endianness convention (used everywhere in qsym):
;;   - Little-endian: bit i of a state index k is the value of qubit i.
;;   - Bit strings are printed MSB-first so qubit 0 is the rightmost character.

(require math/matrix
         racket/math)

(provide
 tensor-product
 matrix-~=
 matrix-adjoint
 matrix-unitary?
 fourier-matrix
 inverse-fourier-matrix
 index->bits
 bits->index
 index->bit-string)

;; Kronecker (tensor) product A⊗B.
;; Element (i,j) = A[i/r2, j/c2] × B[i%r2, j%c2].
(define (tensor-product m1 m2)
  (let ([r2 (matrix-num-rows m2)]
        [c2 (matrix-num-cols m2)])
    (build-matrix (* (matrix-num-rows m1) r2)
                  (* (matrix-num-cols m1) c2)
                  (λ (i j)
                    (* (matrix-ref m1 (quotient i r2) (quotient j c2))
                       (matrix-ref m2 (remainder i r2) (remainder j c2)))))))

;; True iff every element of m1 and m2 differs by less than tol in magnitude.
(define (matrix-~= m1 m2 [tol 1e-9])
  (and (= (matrix-num-rows m1) (matrix-num-rows m2))
       (= (matrix-num-cols m1) (matrix-num-cols m2))
       (for*/and ([i (in-range (matrix-num-rows m1))]
                  [j (in-range (matrix-num-cols m1))])
         (< (magnitude (- (matrix-ref m1 i j) (matrix-ref m2 i j))) tol))))

;; Conjugate-transpose (Hermitian adjoint, †) of a matrix.
(define (matrix-adjoint m)
  (matrix-transpose (matrix-map conjugate m)))

;; True iff m†m ≈ I (m is unitary) within tolerance tol.
(define (matrix-unitary? m [tol 1e-9])
  (matrix-~= (matrix* (matrix-adjoint m) m)
             (identity-matrix (matrix-num-rows m))
             tol))

;; N×N discrete Fourier transform matrix, normalized by 1/√N.
;; F[r,c] = exp(2πi·r·c/N) / √N.
(define (fourier-matrix N)
  (build-matrix N N
                (λ (r c)
                  (/ (exp (* (/ (* 2.0 pi) N) 0+1i r c))
                     (sqrt N)))))

;; N×N inverse discrete Fourier transform matrix, normalized by 1/√N.
;; F†[r,c] = exp(-2πi·r·c/N) / √N.
(define (inverse-fourier-matrix N)
  (build-matrix N N
                (λ (r c)
                  (/ (exp (* (/ (* -2.0 pi) N) 0+1i r c))
                     (sqrt N)))))

;; List of n bits for state index k; position i holds bit i of k (qubit i).
(define (index->bits n k)
  (for/list ([i (in-range n)])
    (bitwise-and (arithmetic-shift k (- i)) 1)))

;; State index for a list of bits where position i is qubit i (little-endian).
(define (bits->index bits)
  (for/fold ([idx 0])
            ([b bits]
             [i (in-naturals)])
    (+ idx (* b (expt 2 i)))))

;; MSB-first binary string for state index k in an n-qubit register.
;; Qubit 0 is the rightmost character (Qiskit convention).
(define (index->bit-string n k)
  (list->string
   (for/list ([i (in-range (- n 1) -1 -1)])
     (if (= (bitwise-and (arithmetic-shift k (- i)) 1) 1)
         #\1
         #\0))))
