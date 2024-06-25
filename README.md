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


