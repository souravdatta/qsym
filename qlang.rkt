#lang racket

(require "qsym.rkt")


(define (q-registers cir)
  (first (second cir)))

(define (layer xs n)
  (let* ([ls (map (λ (l) (list (second l)
                               (if (> (length l) 2)
                                   l
                                   (first l))))
                  xs)]
         [lls (for/list ([x (range n)])
                (let ([v (assoc x ls)])
                  (if v
                      (second v)
                      'i)))])
    (let ([complex (findf list? lls)])
      (if (and complex (> (length complex) 2))
          (list complex)
          lls))))
                 
(define (layers cir n)
  (map (λ (l) (layer (cdr l) n))
       (cddr cir)))

(define (map-gate x n)
  (if (list? x)
      (cond
        ((eq? (first x) 'cx) (gate-matrix n
                                          (list (list (rest x)
                                                      cnot-f))))
        ((eq? (first x) 'rx) (Rx (second x)))
        ((eq? (first x) 'ry) (Ry (second x)))
        ((eq? (first x) 'rz) (Rz (second x)))
        (else (I n)))
      (cond
        ((eq? x 'x) X)
        ((eq? x 'h) H)
        ((eq? x 'z) Z)
        ((eq? x 'y) Y)
        (else I2))))

(define (layers->matrices layers n)
  (map (λ (layer)
         (if (= (length layer) 1)
             (map-gate (first layer) n)
             (map (λ (l) (map-gate l n)) layer)))
       layers))

(define (gen-spaces v n)
  (let* ([len (string-length (format "~a" v))]
         [rem-len (if (> len n) 0 (- n len))])
    (make-string rem-len #\space)))

(define (draw-circuit cir)
  (let* ([num-regs (q-registers cir)]
         [lrs (layers cir num-regs)])
    (for ([i (range num-regs)])
      (for ([l lrs])
        (if (and (> num-regs 1) (= (length l) 1))
            (display (format "|< ~a >|" (first l)))
            (let ([v (list-ref l i)])
              (display (format "|  ~a~a|" v (gen-spaces v 8)))))
        (display " -> "))
      (displayln ""))))

(define (sv-simulator cir)
  (let* ([num-regs (q-registers cir)]
         [lrs (layers cir num-regs)]
         [glrs (layers->matrices lrs num-regs)])
    (make-circuit glrs)))
      
;; (define c1 '(circuit (3)
;;                      (layer (z 2)
;;                             (h 1))
;;                      (layer (cx 0 2))
;;                      (layer ((rx 30) 0))))
;; 

;; |  i       | -> |< (cx 0 2) >| -> |  (rx 30) | -> 
;; |  h       | -> |< (cx 0 2) >| -> |  i       | -> 
;; |  z       | -> |< (cx 0 2) >| -> |  i       | -> 
