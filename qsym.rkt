#lang racket

;; Copyright Sourav Datta (soura.jagat@gmail.com)
;; You should have received a copy of the LICENSE along with this code
;; in the repository. If not refer to
;; https://github.com/souravdatta/qsym/blob/main/LICENSE


(require math/matrix)
(require math/array)

(define (e-equal? x y)
  (< (abs (- x y)) 0.00001))

(define (qubit a b)
  (if (e-equal? (+ (* (magnitude a)
                      (magnitude a))
                   (* (magnitude b)
                      (magnitude b)))
                1.0)
      (col-matrix [a b])
      (error "Cannot create qubit, bad probabilities")))

(define q0 (qubit 1 0))

(define ((apply-op op-matrix) q)
  (matrix* op-matrix q))

(define pauli-x (matrix [[0 1]
                         [1 0]]))

(define gX (apply-op pauli-x))

(define pauli-z (matrix [[1 0]
                         [0 -1]]))

(define gZ (apply-op pauli-z))

(define pauli-y (matrix [[0 0-i]
                         [0+i 0]]))

(define gY (apply-op pauli-y))

(define h-factor (/ 1.0 (sqrt 2)))

(define hadamard (matrix [[h-factor h-factor]
                          [h-factor (- h-factor)]]))

(define gH (apply-op hadamard))

;; shortcuts
(define H hadamard)
(define X pauli-x)
(define Y pauli-y)
(define Z pauli-z)

;; -----

(define (bits-of-len n)
  (cond
    ((< n 1) (error "Invalid bits length, must be >= 1"))
    ((= n 1) '((0) (1)))
    (else (let ([lower-bits (bits-of-len (- n 1))])
            (for*/list ([i (range 2)]
                        [x lower-bits])
              (cons i x))))))

(define (bits->decimal bits)
  (for/fold ([dec 0])
            ([x (reverse bits)]
             [n (range (length bits))])
    (+ dec (* x (expt 2 n)))))

(define (bits->colv bits)
  (let* ([n (length bits)]
         [N (expt 2 n)]
         [output (make-list N 0)]
         [decimal (bits->decimal bits)])
    (list-update output decimal (λ (x) 1))))

(define (range-map start probs obs roll i n)
  (if (= i n)
      (error "No observation from circuit - invalid state")
      (if (= (list-ref probs i) 0)
          (range-map start
                     probs
                     obs
                     roll
                     (+ i 1)
                     n)
          (if (and (>= roll start)
                   (< roll (+ start (list-ref probs i))))
              (list-ref obs i)
              (range-map (+ start (list-ref probs i)) ; next start
                         probs
                         obs
                         roll
                         (+ i 1)            ; next observation to match
                         n)))))

(define (measure-mat m)
  (let* ([len (matrix-num-rows m)]
         [blen (exact-round (log len 2))]
         [obs (bits-of-len blen)]
         [ampls (matrix->list m)]
         [scaled-probs (map (λ (x) (*  x x 100)) ampls)]
         [roll (random 100)])
    (range-map 0 scaled-probs obs roll 0 len)))

(define (counts q #:shots [shots 1024])
  (let ([results (make-hash)])
    (for ([i (range shots)])
      (let ([obs (measure-mat q)])
        (if (hash-has-key? results obs)
            (hash-set! results obs (+ (hash-ref results obs) 1))
            (hash-set! results obs 1))))
    results))

(define (tensor* m1 m2)
  (define (mat->list m1 m2)
    (matrix->list*
     (matrix-map (λ (x)
                   (matrix->list*
                    (matrix-map (λ (y)
                                  (* x y))
                                m2)))
                 m1)))

  (define (list->mat m)
    (let ([rows '()])
      (for ([row m])
        (for ([i (range (length (first row)))])
          (let ([row-line '()])
            (for ([m row])
              (set! row-line (append row-line (list-ref m i))))
            (set! rows (append rows (list row-line))))))
      rows))
  (let* ([m (mat->list m1 m2)]
         [l (list->mat m)])
    (list*->matrix l)))

(define (t* . qbits)
  (let ([n (length qbits)])
    (cond
      ((< n 1) (error "No qubits given"))
      ((= n 1) (first qbits))
      (else (tensor* (first qbits)
                     (apply t* (rest qbits)))))))

(define (I n)
  (identity-matrix n))

(define (nG* . ms) ;; native order
  (apply-op (apply t* ms)))

(define (G* . ms)  ;; qiskit compatible
  (apply-op (apply t* (reverse ms))))

(define (qubits n)
  (apply t* (for/list ([i (range n)])
              q0)))

(define (make-circuit matrices #:assembler [assembler G*])
  (let ([ops (map (λ (gs) (if (list? gs)
                              (apply assembler gs)
                              (apply-op gs)))
                  matrices)])
    (λ (input-qbits)
      (for/fold ([sv input-qbits])
                ([f ops])
        (f sv)))))

;;;;;;;;;

(define (transform-rule input rule)
  (let* ([ixs (first rule)]
         [f (second rule)]
         [input-ixs (for/list ([x ixs])
                      (list-ref input x))]
         [output-vs (apply f input-ixs)])
    (let ([output input])
      (for/list ([i (range (length input))])
        (if (member i ixs)
            (let ([vh (first output-vs)])
              (set! output-vs (rest output-vs))
              vh)
            (list-ref input i))))))

(define (transform-rules input rules)
  (for/fold ([i input])
            ([r rules])
    (transform-rule i r)))

(define (gate-matrix n tx-rules)
  (let* ([inputs (bits-of-len n)]
         [coords (for/list ([i inputs])
                   (transform-rules (reverse i) ;; msb -> lsb
                                    tx-rules))]
         [lsb-coords (map reverse coords)])
    (matrix-transpose
     (list*->matrix
      (map bits->colv lsb-coords)))))

;;;;;;;;;

(define (cnot-f control target)
  (if (= control 1)
      (list control (if (= target 1) 0 1))
      (list control target)))

(define cnot-gate (gate-matrix 2
                               (list (list '(0 1)
                                           cnot-f))))

(define CX cnot-gate)
(define gCX (apply-op cnot-gate))

   
;;;;;;;;;
;; QFT
;;;;;;;;;

(define (w k n N)
  (exp (*
        (/ (* 2 pi)
           N)
        0+1i
        n
        k)))

(define (w-inverse k n N)
  (exp (*
        (/ (* -2 pi)
           N)
        0+1i
        n
        k)))

(define (fourier-matrix N)
  (matrix-map
   (λ (x)
     (/ x
        (sqrt N)))
   (list*->matrix
    (for/list ([n (range 0 N)])
      (for/list ([k (range 0 N)])
        (w k n N))))))

(define (inverse-fourier-matrix N)
  (matrix-map
   (λ (x)
     (/ x
        (sqrt N)))
   (list*->matrix
    (for/list ([n (range 0 N)])
      (for/list ([k (range 0 N)])
        (w-inverse k n N))))))

(define F fourier-matrix)
(define Fi inverse-fourier-matrix)

(provide (all-defined-out))
