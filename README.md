## A simple library for simulating quantum computing

Check out the [tutorial](https://github.com/souravdatta/qsym/blob/main/qsym_tutorial.md) for details.

### Quick example - super dense coding

```racket
(define c1 (def-circuit 2
             (def-layer (h 0))
             (def-layer (cx 0 1))
             (def-layer (z 0))
             (def-layer (cx 0 1))
             (def-layer (h 0))))

(draw-circuit c1)
(plot-histogram (counts ((sv-simulator c1) (qubits 2))))
```

```
|  h       | -> |< (cx 0 1) >| -> |  z       | -> |< (cx 0 1) >| -> |  h       | -> 
|  i       | -> |< (cx 0 1) >| -> |  i       | -> |< (cx 0 1) >| -> |  i       | ->
```


![plot](https://github.com/souravdatta/qsym/assets/1576318/fe93307e-d7a3-4142-ad38-5ff82670aa3e)

### Another example with multiple entanglements

<img width="596" alt="image" src="https://github.com/souravdatta/qsym/assets/1576318/412fe80a-7783-4b67-a5d6-512d6dce5fa9">

### Bernstein-Vazirani algorithm

Implement an oracle to decode string `10011`

First, using `qlang` which is an easy to write small circuits but is less flexible. Also, it can draw the circuit in a crude form.
```racket
(define oracle2 (list
                (def-layer (cx 0 5))
                (def-layer (cx 1 5))
                (def-layer (cx 4 5))))

;; helper function
(define (hgates n)
  (for/list ([i (range n)])
    (list 'h i)))

(define c (def-circuit 6
              (def-layer (x 5))
              (list->layer (hgates 6))
              oracle2 ;; the secret oracle that encode a string
              (list->layer (hgates 6))))

(define sim (sv-simulator c))
(plot-histogram
 (counts (sim (qubits 6)))) ; This should reveal 1<secret string from oracle - 10011> with max prob

(draw-circuit c)
```

```
;; |                 | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |                 | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |                 | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |                 | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |                 | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
;; |  x              | -> |  h              | -> |< (cx 0 5) >| -> |< (cx 1 5) >| -> |< (cx 4 5) >| -> |  h              | -> 
```

<img width="410" alt="image" src="https://github.com/souravdatta/qsym/assets/1576318/17599c76-42e3-411a-b2f7-acab00f4fd44">

Second, using the original `list` form - this is more flexible as one can manipulate the data in any way needed. But we can't draw circuits from it (yet).

```racket
;; Oracle for 10011
(define oracle (gate-matrix 6
                            (list
                             (list '(0 5)
                                   cnot-f)
                             (list '(1 5)
                                   cnot-f)
                             (list '(4 5)
                                   cnot-f))))

(define cirq
  (make-circuit (list
                 (list (I 2)
                       (I 2)
                       (I 2)
                       (I 2)
                       (I 2)
                       X)
                 (make-list 6 H)
                 oracle
                 (make-list 6 H))))


(define input (qubits 6))

(define r (cirq input))

(plot-histogram
 (counts r #:shots 2000)) ;; 110011 with close 100% probability
```

Choosing `qlang` vs normal `qsym` is a matter of how complex the circuit is. If it is a small one, prefer `qlang`. If more complexity and reusability is required, use direct `qsym` `make-circuit` function.


