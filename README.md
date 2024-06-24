## A simple library for simulating quantum computing

Check out the [tutorial](https://github.com/souravdatta/qsym/blob/main/qsym_tutorial.md) for details.

### Quick example - super dense coding

```racket
(define c1 '(circuit (2)
                     (layer (h 0))
                     (layer (cx 0 1))
                     (layer (z 0))
                     (layer (cx 0 1))
                     (layer (h 0))))

(draw-circuit c1)
(plot-histogram (counts ((sv-simulator c1) (qubits 2))))
```

```
|  h       | -> |< (cx 0 1) >| -> |  z       | -> |< (cx 0 1) >| -> |  h       | -> 
|  i       | -> |< (cx 0 1) >| -> |  i       | -> |< (cx 0 1) >| -> |  i       | ->
```


![plot](https://github.com/souravdatta/qsym/assets/1576318/fe93307e-d7a3-4142-ad38-5ff82670aa3e)
