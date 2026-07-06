#lang racket

;; Superdense coding: Alice encodes 2 classical bits into 1 qubit using a
;; shared Bell pair and sends it to Bob, who decodes both bits.

(require qsym)

;; Superdense encoding: b1 is the high bit, b0 is the low bit.
;; Alice applies Z if b0=1, X if b1=1, to her qubit of the Bell pair.
(define (superdense b1 b0)
  (make-circuit
   (append (list (list H ID) CX)
           (if (= b0 1) (list (list Z ID)) '())
           (if (= b1 1) (list (list X ID)) '())
           (list CX
                 (list H ID)
                 (measure 0 1)))
   #:clbits 2))

(define input (qubits 2))

(displayln "Superdense coding — message vs. Bob's measurement:")
(for* ([b1 '(0 1)] [b0 '(0 1)])
  (define c (run-shots (superdense b1 b0) input #:shots 200 #:seed 1))
  (displayln (format "  send (~a,~a): got ~a" b1 b0 (hash-keys c))))
