#lang racket

(require rackunit
         math/matrix
         "../private/linalg.rkt")

;; ---- tensor-product ----

(test-case "tensor-product: I2⊗I2 = I4"
  (check-true
   (matrix-~= (tensor-product (identity-matrix 2) (identity-matrix 2))
              (identity-matrix 4))))

(test-case "tensor-product: X⊗I2 maps to correct 4×4 matrix"
  (let ([X   (matrix [[0 1] [1 0]])]
        [I2  (identity-matrix 2)]
        [expected (matrix [[0 0 1 0]
                           [0 0 0 1]
                           [1 0 0 0]
                           [0 1 0 0]])])
    (check-true (matrix-~= (tensor-product X I2) expected))))

(test-case "tensor-product: dimensions for 3 copies of I2"
  (let ([m (tensor-product (identity-matrix 2)
                           (tensor-product (identity-matrix 2)
                                           (identity-matrix 2)))])
    (check-equal? (matrix-num-rows m) 8)
    (check-equal? (matrix-num-cols m) 8)))

(test-case "tensor-product: I2⊗I2⊗I2 = I8"
  (let ([m (tensor-product (identity-matrix 2)
                           (tensor-product (identity-matrix 2)
                                           (identity-matrix 2)))])
    (check-true (matrix-~= m (identity-matrix 8)))))

(test-case "tensor-product: non-square matrices"
  (let ([A (matrix [[1 0] [0 1] [0 0]])]  ; 3×2
        [B (matrix [[1 2] [3 4]])])        ; 2×2
    (let ([C (tensor-product A B)])
      (check-equal? (matrix-num-rows C) 6)
      (check-equal? (matrix-num-cols C) 4))))

;; ---- matrix-~= ----

(test-case "matrix-~=: matrix equals itself"
  (let ([m (matrix [[1+1i 2] [3 4-2i]])])
    (check-true (matrix-~= m m))))

(test-case "matrix-~=: different values → false"
  (check-false (matrix-~= (matrix [[1 0] [0 1]])
                           (matrix [[1 0] [0 2]]))))

(test-case "matrix-~=: dimension mismatch → false"
  (check-false (matrix-~= (identity-matrix 2) (identity-matrix 4))))

(test-case "matrix-~=: custom tolerance accepted"
  (let ([m1 (matrix [[1.0 0.0] [0.0 1.0]])]
        [m2 (matrix [[1.001 0.0] [0.0 1.0]])])
    (check-false (matrix-~= m1 m2 1e-9))
    (check-true  (matrix-~= m1 m2 0.01))))

;; ---- matrix-adjoint ----

(test-case "matrix-adjoint: adjoint of I = I"
  (check-true (matrix-~= (matrix-adjoint (identity-matrix 4)) (identity-matrix 4))))

(test-case "matrix-adjoint: adjoint of real symmetric = itself"
  (let ([m (matrix [[1 2] [2 4]])])
    (check-true (matrix-~= (matrix-adjoint m) m))))

(test-case "matrix-adjoint: adjoint swaps row/col and conjugates"
  (let ([m (matrix [[1+2i 3+4i] [5+6i 7+8i]])])
    (let ([md (matrix-adjoint m)])
      (check-true (< (magnitude (- (matrix-ref md 0 0) 1-2i)) 1e-9))
      (check-true (< (magnitude (- (matrix-ref md 0 1) 5-6i)) 1e-9))
      (check-true (< (magnitude (- (matrix-ref md 1 0) 3-4i)) 1e-9))
      (check-true (< (magnitude (- (matrix-ref md 1 1) 7-8i)) 1e-9)))))

;; ---- matrix-unitary? ----

(test-case "matrix-unitary?: identity matrices are unitary"
  (for ([n '(1 2 4 8)])
    (check-true (matrix-unitary? (identity-matrix n)))))

(test-case "matrix-unitary?: non-unitary matrix"
  (check-false (matrix-unitary? (matrix [[2 0] [0 1]]))))

(test-case "matrix-unitary?: Hadamard is unitary"
  (let ([h-factor (/ 1.0 (sqrt 2.0))])
    (check-true (matrix-unitary?
                 (matrix [[h-factor  h-factor]
                           [h-factor (- h-factor)]])))))

;; ---- fourier-matrix / inverse-fourier-matrix ----

(test-case "fourier-matrix 4 is unitary"
  (check-true (matrix-unitary? (fourier-matrix 4))))

(test-case "fourier-matrix 8 is unitary"
  (check-true (matrix-unitary? (fourier-matrix 8))))

(test-case "inverse-fourier-matrix 4 is unitary"
  (check-true (matrix-unitary? (inverse-fourier-matrix 4))))

(test-case "fourier × inverse = identity (N=4)"
  (let ([N 4])
    (check-true (matrix-~= (matrix* (inverse-fourier-matrix N) (fourier-matrix N))
                            (identity-matrix N)))))

(test-case "fourier × inverse = identity (N=8)"
  (let ([N 8])
    (check-true (matrix-~= (matrix* (inverse-fourier-matrix N) (fourier-matrix N))
                            (identity-matrix N)))))

(test-case "fourier-matrix F[0,j] = 1/√N for all j (first row is uniform)"
  (let* ([N 4]
         [F (fourier-matrix N)]
         [expected (/ 1.0 (sqrt N))])
    (for ([j (in-range N)])
      (check-= (magnitude (matrix-ref F 0 j)) expected 1e-9))))

;; ---- bit conversions ----

(test-case "index->bits 3 5 = '(1 0 1)"
  (check-equal? (index->bits 3 5) '(1 0 1)))

(test-case "index->bits 3 0 = '(0 0 0)"
  (check-equal? (index->bits 3 0) '(0 0 0)))

(test-case "index->bits 3 7 = '(1 1 1)"
  (check-equal? (index->bits 3 7) '(1 1 1)))

(test-case "index->bits 3 3 = '(1 1 0)"
  (check-equal? (index->bits 3 3) '(1 1 0)))

(test-case "bits->index '(1 0 1) = 5"
  (check-equal? (bits->index '(1 0 1)) 5))

(test-case "bits->index '(0 0 0) = 0"
  (check-equal? (bits->index '(0 0 0)) 0))

(test-case "bits->index '(1 1 0) = 3"
  (check-equal? (bits->index '(1 1 0)) 3))

(test-case "bits->index round-trips with index->bits for n=1..4"
  (for ([n (in-range 1 5)])
    (for ([k (in-range (expt 2 n))])
      (check-equal? (bits->index (index->bits n k)) k))))

(test-case "index->bit-string 3 5 = \"101\""
  (check-equal? (index->bit-string 3 5) "101"))

(test-case "index->bit-string 3 0 = \"000\""
  (check-equal? (index->bit-string 3 0) "000"))

(test-case "index->bit-string 3 7 = \"111\""
  (check-equal? (index->bit-string 3 7) "111"))

(test-case "index->bit-string 3 3 = \"011\""
  (check-equal? (index->bit-string 3 3) "011"))

(test-case "index->bit-string 1 1 = \"1\""
  (check-equal? (index->bit-string 1 1) "1"))

(test-case "index->bit-string round-trip: parse back to integer"
  (for ([n (in-range 1 5)])
    (for ([k (in-range (expt 2 n))])
      (let ([s (index->bit-string n k)])
        ;; The string has n characters; parsing it as binary gives k.
        (check-equal? (string->number s 2) k)))))
