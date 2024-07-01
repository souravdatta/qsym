#lang racket

;; Copyright Sourav Datta (soura.jagat@gmail.com)
;; You should have received a copy of the LICENSE along with this code
;; in the repository. If not refer to
;; https://github.com/souravdatta/qsym/blob/main/LICENSE


(require "qsym.rkt")

(random-seed 43211234)

(define (bit->qubit b)
  (if (= b 0)
      q0
      (gX q0)))

(define (qubit-message bs)
  (map bit->qubit bs))

(define (rand-gate)
  (let ([r (random 2)])
    (if (= r 0)
        'h
        'z)))

(define (apply-gate g q)
  (if (eq? g 'h)
      (gH q)
      (gZ q)))

(define (encode-msg bs)
  (let ([gs (for/list ([i (length bs)])
              (rand-gate))])
    (list gs
          (map apply-gate
               gs
               (qubit-message bs)))))

(define (decode-msg svl)
  (let ([gs (for/list ([i (length svl)])
              (rand-gate))])
    (list gs
          (map apply-gate
               gs
               svl))))

(define secret '(1 0 0 1 1 0 1 1 0 1 0 0 0 1 1 0 1 1 1 1))

(define (same-encodings gs1 gs2)
  (let ([ixs '()]
        [c 0])
    (for ([i (range (length gs1))])
      (when (eq?
             (list-ref gs1 i)
             (list-ref gs2 i))
        (set! ixs (cons i ixs))
        (set! c (+ c 1))))
    (list (reverse ixs) c)))

(define (qubits->bits qs)
  (flatten
   (map measure-mat qs)))

(define (alice secret)
  (encode-msg secret))

(define (tally-bits orig-secret decoded-bob)
  (let* ([cs (third decoded-bob)]
         [rbits (qubits->bits (second decoded-bob))]
         [match-ixs (first cs)]
         [gcs (second cs)]
         [acs 0])
    (for ([i match-ixs])
      (when (= (list-ref orig-secret i)
               (list-ref rbits i))
        (set! acs (+ acs 1))))
    (list acs gcs)))

(define ((bob msg) gs)
  (let ([d-msg (decode-msg msg)])
    (list (first d-msg)
          (second d-msg)
          (same-encodings gs
                          (first d-msg))
          (length gs))))

(define (eve msg)
  (let* ([d-msg (decode-msg msg)]
         [gs (first d-msg)]
         [qbs (second d-msg)]
         [secret1 (qubits->bits qbs)]
         [re-encoded (second (encode-msg secret1))])
    (displayln "... [inside Eve's process]")
    (displayln secret1)
    (displayln gs)
    (displayln "...")
    re-encoded))

(displayln "secret")
(displayln secret)
(displayln (length secret))
(define msg (alice secret))
(displayln (first msg))

(displayln "without Eve")
(define b1 (bob (second msg)))
(define bob1 (b1 (first msg)))
(displayln "tally")
(tally-bits secret bob1)

(displayln "with Eve")
(define e (eve (second msg)))
(define b2 (bob e))
(define bob2 (b2 (first msg)))
(displayln "tally")
(tally-bits secret bob2)
