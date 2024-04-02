# Building a Quantum Simulator from Scratch

## Introduction
Lets dive in and build a simulator for a quantum computer (QC) from scratch, one step at a time. But before we go into the code, lets look at `what`s and `why`s.

#### What is it?
There are great quantum simulators from almost every vendor who builds real quantum computers today, the most popular among those (IMHO) being [Qiskit](https://www.ibm.com/quantum/qiskit). These libraries have
support for all sorts of quantum gates and circuits and they are developed by many developers - both paid and open source. This, is not that! This is a very small subset of quantum gates and mechanisms to build
circuits using those. In fact, its so small that it is just one file! 

#### So then why does it exist?
1. Building something from scratch gives you a lot of knowledge of how the internals actually work. There's a lot of theory in QC which are expressed in mathematical operations. These operations are simulated into the actual quantum circuit on a real hardware, but while writing the code and thinking about those conceptually, it is all a series of mathematical steps. Looking at a code in Qiskit can give you some idea about how it looks externally, but not a lot about how it works internally.
2. Libraries like Qiskit are heavyweight and they require a lot of dependencies to run. I failed many times trying to install Qiskit on a raspberry Pi. A smaller simulator can be made to work on any computer with some speed constraints.
3. You have the freedom to make it look like however you want. May be I don't like the endianness of Qiskit and I want it to be the opposite (more on it later), I probably can't do that on a prebuilt library. But I can do it in my own code.
4. Finally, its just a lot of fun, so why not!

Convinced? Dive in then!

### The language of the system
We will use something different, not Python please! :-D Although I really love Python I think if we want to do something from scratch it would be nice to use something different which does not have megatons of libraries already available.
Being a life long Lisp lovers, I decided to use a Lisp instead. There're some main streams dialects we could use - Common Lisp (the Lisp), Clojure and Racket. Since we would be using a bit of linear algebra and only Racket comes with a "battery included" for Matrices, I went with Racket.

##### Racket
[Racket](https://racket-lang.org/) is a nice eco-system that actually embodies the idea of Python's batteries included more than Python. It can be downloaded and installed in a ziffy and it comes with Dr. Racket IDE which more than good enough.

##### A bit about types
Racket is a dialect of Scheme, which is a dialect of Lisp. Racket extends and adds many more concepts on top of a typical Scheme distribution. One of these new features is the concept of sub languages. Racket by default is a dynamically typed language but one of the sub languages is a `typed/racket`. However, here we have stuck to the default dynamically typed
version of Racket. But, the code can be converted to typed Racket code and it can be used from other `typed/racket` code as well.

## Part 1 - From Bits to Qubits

Our computers work with `bits`. Bits are used for storing binary data. All our software work with binary data and we have been optimizing our computers to work more of binary data and with more speed. We will see that in the quantum domain, we still have the concept of binary data but not exactly as it is in the "classical" domain. So, lets start with our familiar good old classical bit.

#### Representing classical bits
How do we show a classical bit? Its easy, either write `0` or `1`. That's because a bit can either be in state `0` or `1`. In hardware, this could be that a 5 volt charge can represent 1 and 0 volt can represent 0. Current hardware and SSD disks are much advanced, but the basic concept is the same. What about two bits? Two bits can be in various different combinations of states, because if one is `0` the other can be either `0` or `1` abd vice versa. So, these are possible states: `00`, `01`, `10`, `11`. In a little math terms, if we have `n` bits, there can be `2^n` combinations in total. This is good, but we can represent the same thing with a little different manner, which will be very useful when we go to qubits. This representation does not list out all the combinations individually, but rather shows which value among all combinations should be turned on. Lets look at it in action. For `n = 2`, we know that we will have `2^2 = 4` combinations, which we saw earlier. This means if I create a list of 4 elements, I can map an element in the list to one of the combinations. A list like `[a, b, c, d]` can be used to map like this: `a => 00, b => 01, c => 10, d => 11`. But since, at any moment, only one of these 4 combinations can be present, it means out of `a, b, c and d` only one value can be present at a time, but not all. So then simplifying the mapping a bit, we say, `[1, 0, 0, 0]` means `00`. Similarly, `[0, 1, 0, 0]` means `01`; `[0, 0, 1, 0]` means `10`; `[0, 0, 0, 1]` means `11`. 

So, that was 2 bits. How about the original single bit? To represent that we now have two lists: bit `0` is `[1, 0]` and bit `1` is `[0, 1]`.

Nice, but remember math? In math there's no lists, but we have `vectors`. The list that we created above for representing bit combinations are repsented as column vectors in Linear Algebra. What's a column vector? It is just the same list but written top to bottom.

Again, bit `0` is 
```
[1
 0]
```
And bit `1` is
```
[0
 1]
```

Bit `01` is
```
[0
 1
 0
 0]
```
Bit `11` is
```
[0
 0
 0
 1]
```
And so on.

#### Code for classical bits
As we have seen above we talked about ways to combine bits and also representing them with `column` vectors. Lets write some code to find all combinations of bits given a bit length.

```racket
(define (bits-of-len n)
  (cond
    ((< n 1) (error "Invalid bits length, must be >= 1"))
    ((= n 1) '((0) (1)))
    (else (let ([lower-bits (bits-of-len (- n 1))])
            (for*/list ([i (range 2)]
                        [x lower-bits])
              (cons i x))))))
```

Running it `(bits-of-len 2)` will give the following output:
```
'((0 0) (0 1) (1 0) (1 1))
```
This is pretty much the same combinations before, but in a list of list - there's a reason we chose Lisp!

How do we represent the other representation? We use [`col-matrix`](https://docs.racket-lang.org/math/matrix_construction.html#%28form._%28%28lib._math%2Fmatrix..rkt%29._col-matrix%29%29) that comes with Racket. We can represent `00` like `(col-matrix [1 0 0 0])`. Which produces this output:

```
(array #[#[1] #[0] #[0] #[0]])
```

Internally it is an array of array - where each row is represented by an inner array.

#### Qubits - welcome to the world of probabilities
In classical world, everything is deterministic. If I have a bit `b` I know that I will always get either
bit `0` which is 
```
[1
 0]
```
or bit `1` which is
```
[0
 1]
```
A qubit, or quantum bit, is almost same as above. The two states of a single qubit are represented as `|0>` and `|1>`, and in colum vector form, again they are same:

Qubit `|0>` is 
```
[1
 0]
```
And qubit `|1>` is
```
[0
 1]
```

So, what's so special? Well, here's what:

A qubit can be either in |0> state or |1> state, or any state in between. This is called superposition state of the qubit.

Which means a qubit `q` can be either of,

1.
```
[1
 0]
```

2.
```
[0
 1]
```

3.
```
[a
 b]
```
Where, the probability formula for `a` and `b` is `a^2 + b^2 = 1`. Here `a` and `b` are `complex` numbers. And the weird thing is, until we measure the qubit, it can be in a superposition state; but as soon as we measure the qubit, it collapses into one of `|0>` or `|1>` states! (Insert your favorite quote from Richard Fyenman about quantum weirdness here)

The third from above is the general way we represent a qubit. As we can see, if b = 0 then we get `|0>` and if a = 0 we get `|1>`. This is what differentiates a classical bit's column vector from a qubit's column vector. In classical bits, the column vector can never have anything other than 1 in the rows. And that too only one of the rows can be `1` at a time. For qubits it can be any complex numbers at any row of the column vector, as long as they all when squared and summed make 1.

However, the property of superposition, and some others like entaglement, gives qubits and QC the edge over classical computing.

#### Code to build a qubit
Now we write a helper method to build a qubit from two values `a` and `b`.

```racket
(define (qubit a b)
  (if (e-equal? (+ (* (magnitude a)
                      (magnitude a))
                   (* (magnitude b)
                      (magnitude b)))
                1.0)
      (col-matrix [a b])
      (error "Cannot create qubit, bad probabilities")))
```

The `magnitude` function determines the correct absolute value (or `norm`) of a complex number. The `e-equal?` is a predicate that determines if the value is sufficently close to 1.0. It is defined as:

```racket
(define (e-equal? x y)
  (< (abs (- x y)) 0.00001))
```

Lets run it few times

```racket
(qubit 1 0) ==> (array #[#[1] #[0]])
(qubit 0 1) ==> (array #[#[0] #[1]])
(qubit 2 3) ==> Cannot create qubit, bad probabilities
(qubit (/ 1 (sqrt 2))
       (/ 1 (sqrt 2))) ==> (array #[#[0.7071067811865475] #[0.7071067811865475]])
```

That last qubit is really special - it has equal chance of being a `|0>` or `|1>`.

## Part 2 - Operations on Qubits

Now that we have enough code to build both classical and quantum bits, lets explore how we can build systems of multiple qubits and then measure those.

#### One to many

We know how to make one qubit but how do we make a couple of those? Just like a classical bit, `n` number of qubits can take `2^n`. The process is same, we create a column vector of `2^n` rows - but the values in those rows are now complex numbers - the sum of the square of which should add up to 1. The way to build this bigger column vector from smaller column vectors is to find the `tensor product` between qubit matrices (a column vector is a matrix of n by 1). A tensor product works like this -
```
[a b            [p q r
 c d]   tensor*  x y z]

==> [ a * [p q r   b * [p q r 
           x y z]       x y z]
      c * [p q r   d * [p q r
           x y z]       x y z] ]
==> [ ap aq ar bp bq br
      ax ay az bx by bz
      cp cq cr dp dq dr
      cx cy cz dx dy dz ]
```
#### Tensor product code
Implementing the tensor product is tricky. Given I wanted it quick, here's a version that looks more `C` than `Lisp`. But it works!

```racket
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
```
We do a bit of juggling between matrix form and list form to make the iterative algorithm easy to write, but I am sure there's a better version that can work directly on the matrix.

Following is a little utility function that takes any number of matrices and returns the tensor product of them all.

```racket
(define (t* . qbits)
  (let ([n (length qbits)])
    (cond
      ((< n 1) (error "No qubits given"))
      ((= n 1) (first qbits))
      (else (tensor* (first qbits)
                     (apply t* (rest qbits)))))))
```

Lets create a pair of qubits by tensor product.

```racket
;; |0> and |1> making |01>
(t* (qubit 1 0)
    (qubit 0 1)) ==> (array #[#[0] #[1] #[0] #[0]])

;; |1> and |1> making |11> 
(t* (qubit 0 1)
    (qubit 0 1)) ==> (array #[#[0] #[0] #[0] #[1]])
```

Comparing to our classical counterpart, we see the tensor product actually creates the same kind of column vector. But here's one with non-trivial probabilities:

```racket
(t* (qubit (/ 1 (sqrt 2))
           (/ 1 (sqrt 2)))
    (qubit 1 0)) ==> (array #[#[0.7071067811865475] #[0] #[0.7071067811865475] #[0]])
```
Now we see the fun of quantum computing. Given a combination of one qubit with 50% chance of being either `|0>` or `|1>` and another with 100% chance of being `|0>` - the combination is 50% `|00>` and 50% `|10>`! What are these chances we are talking about? These chances are finding these qubit combinations (i.e. `00` or `01`) when we measure them. So, lets measure some qubits next.

#### Measuring qubits

This is where it gets really interesting. We are trying to now simulate a process that works in real life according to quantum mechanics - collapse of wave function! We start with a vector of probabilities and we know that their squares sum up to 1. All these values are probabilities, so if one value is greater than the others, then that has more chance of showing up than others when we measure the qbits combination (also called the state of the quantum system). Here's a simple strategy to simulate this - 

1. We scale the probabilities up by a factor of 100.
2. Now they should all cover the range from 0 - 99. If a probability is zero, we ignore it.
3. We roll a dice and find a value between 0 and 100.
4. We check under which probability region it has fallen. The higher the probability, the bigger the chance that the dice will fall within that region.
5. But there's also a tiny chance that it will fall into the region of the other probabilities - which is what we see in real life too.

Here's how it looks like in a semi-complex recursive definition

```racket
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
```

`range-map` is a tail recursive function which does the heavy lifting of the actual probability mapping operation. There's just one more step remaining to measurement - measuring repeatedly. For a quantum state, if we measure just once we might get some results from its probabilities, but that might not be a true picture of the system. So we have to measure repeatedly and then find counts (or histogram) to see the actual results. Thus, the irregularities of single measurement will smooth out and we should get the actual estimation of the results. Note that we use the `bits-of-len` to map a column matrix to its corresponding `classical` bit combination.

```racket
(define (counts q #:shots [shots 1024])
  (let ([results (make-hash)])
    (for ([i (range shots)])
      (let ([obs (measure-mat q)])
        (if (hash-has-key? results obs)
            (hash-set! results obs (+ (hash-ref results obs) 1))
            (hash-set! results obs 1))))
    results))
```

Now we define a symbol `q0` as a shortcut to `|0>`. Why only `|0>`? Because that's the state all qubits start with in quantum circuits. We will see how we can get `|1>` from `q0`.

```racket
(define q0 (qubit 1 0))
```

Ok, now lets measure some qubits!

```racket
(counts q0) ==> '#hash(((0) . 1024))
```

As expected, if you measure `|0>` then you always get `0`. How about that special state where we 50% chance of getting `0` or `1`?

```racket
(counts (t* (qubit (/ 1 (sqrt 2))
            (/ 1 (sqrt 2))))) ==> '#hash(((0) . 514) ((1) . 510))
```

Look at that! We got almost equal numbers of 0s and 1s.

And finally,

```racket
(counts (t* (qubit (/ 1 (sqrt 2))
                   (/ 1 (sqrt 2)))
            (qubit 1 0))) ==> '#hash(((0 0) . 495) ((1 0) . 529))
```

Believe it or not, this is about all the internal code we need to do cool things like quantum gates!

## Part 3 - Quantum Gates and Circuits

Quantum gates get their name from logic gates in classical circuits. Classical computer circuits can be decomposed into a series of circuits with gates like AND, OR, NOT, NAND or XOR. Similarly, quantum circuits can be built using quantum gates. These gates are actually just matrices but they have special properties.

1. They need to be unitary matrices.
2. The application of the quantum gate needs to be reversible. Logic gates are not reversible but its a must for quantum gates to be reversible.

### Applying a gate to a qubit

How do we apply a gate to a qubit? It is as simple as multiplying two matrices. So if we want to apply `A` gate to qubit `q`, it is: `A * q` where `*` means matrix multiplication. Luckily, Racket already has a function to do that. Lets implement a new function for it.

```racket
(define ((apply-op op-matrix) q)
  (matrix* op-matrix q))
```

Note that it is a higher order function. We will see why very soon. Lets now take a look at few useful gates.

#### X gate

An `X` gate is used to invert a qubit. Conceptually, if a single qubit has probabilities `a` and `b` (both complex numbers), then the reverse qubit has probabilities `b` and `a`! So X gate is a matrix which does exactly that. This is the matrix for X gate (which is one of the Pauli matrices):

```
[0 1
 1 0]
```

In code,

```racket
(define pauli-x (matrix [[0 1]
                         [1 0]]))

(define gX (apply-op pauli-x))
```

Lets see it in action

```racket
;; |0> to |1>
(gX q0) ==> (array #[#[0] #[1]])

;; and back
(gX (gX q0)) ==> (array #[#[1] #[0]])

;; Are they reversible? Yes
(equal? (gX (gX q0))
          q0) ==> #t
```

#### Hadamard gate

This is probably the most famous gate! You will see it almost in every circuit and in plenty. It is defined like below:

```racket
(define h-factor (/ 1.0 (sqrt 2)))

(define hadamard (matrix [[h-factor h-factor]
                          [h-factor (- h-factor)]]))

(define gH (apply-op hadamard))
```

This gate makes a qubit in superposition state with 50-50 chances of measuring `0` or `1`.

```
(gH q0) ==> (array #[#[0.7071067811865475] #[0.7071067811865475]])
(gH (gH q0)) ==> (array #[#[0.9999999999999998] #[0.0]])

;; Put |0> in superposition state
(counts (gH q0)) ==> '#hash(((0) . 513) ((1) . 511))

;; Put |1> in superposition state
(gH (gX q0)) ==> (array #[#[0.7071067811865475] #[-0.7071067811865475]])
```

#### Other Pauli gates

The other Pauli matrices can also be defined as gates.

```racket
(define pauli-z (matrix [[1 0]
                         [0 -1]]))

(define gZ (apply-op pauli-z))

(define pauli-y (matrix [[0 0-i]
                         [0+i 0]]))

(define gY (apply-op pauli-y))
```

Finally, since we will be using these gates quite often, lets define some sortcuts for the matrices that are easy to remember and distinguish in a circuit.

```racket
;; shortcuts
(define H hadamard)
(define X pauli-x)
(define Y pauli-y)
(define Z pauli-z)
```

#### State Vectors and Gates

We were using the term column vectors to refer to the quantum state. The actual term used in code and literature for these column vectors are `state vectors`. The gates basically take a state vector and return a new state vector.

`Gate :: State Vector -> State Vector`

The qubit `q0` itself is just another state vector.

What happens if we have two qubits and we want to apply gates to this state vector of two qubits? Suppose we want to apply `H` gate to the first qubit but not to the second qubit. Lets take this step by step.

1. We know how to put two qubits into a state vector - we use tensor product.
2. We know how to apply a quantum gate to a single qubit - that's matrix multiplication.
3. Then how do we apply H gate to a state vector of two qubits? We can't as the matrices are of incompatible sizes.
4. Solution is - we need to make a bigger matrix for multiplication where part of the matrix is Hadamard matrix, the other part is simply an identity matrix.
5. How do we make the bigger matrix such that the parts fit correctly? Well, turns out we can just use the tensor product on the gates!

```racket
(define (I n)
  (identity-matrix n))
```

`I` function is used to generate an identity matrix of `n` rows and columns. For a single qubit, n = 2 because it has two possible outcomes.

Once we have this defined, lets make a state vector where we apply `H` gate to the first qubit.

```racket

(define new-gate (t* H
                     (I 2)))

(define initial-qubits (t* q0
                          q0))

(define state-vector ((apply-op new-gate) initial-qubits))

state-vector ==> (array #[#[0.7071067811865475] #[0] #[0.7071067811865475] #[0]])
```
Looks good! Now lets validate this agains a similar circuit in Qiskit.


#### Big Endian vs Little Endian

```
     ┌───┐
q_0: ┤ H ├
     └───┘
q_1: ─────
```
       
Here's the code for the equivalent code above in Qiskit:

```Python
from qiskit import *
from qiskit_aer import StatevectorSimulator

circuit = QuantumCircuit(2)
circuit.h(0)

simulator = StatevectorSimulator()
result = simulator.run(circuit).result()
result.get_statevector()
```

The answer we get is 
```
Statevector([0.70710678+0.j, 0.70710678+0.j, 0.        +0.j,
             0.        +0.j],
            dims=(2, 2))
```

It looks like we have all the values correct but the order they appear seems different from our state vector. What's going on?

Turns out, the order of the matrices matter! In our current order, i.e. the `H` above and `(I 2)` below, it makes it a big endian system, where the least significant bit is on the left. However, qiskit and others like `Q#` uses little endian systems - least significant bit is on the right. Although in the circuit diagram we see the least bit at the top, it is intepreted to be on the right! It is confusing but after a bit of back and forth, it becomes normal (well hopefully). So our code is right except our order needs to be opposite for it to match qiskit output. Lets try this:

```racket
(define new-gate (t* (I 2)
                       H))

(define initial-qubits (t* q0
                             q0))

(define state-vector ((apply-op new-gate) initial-qubits))

state-vector ==> (array #[#[0.7071067811865475] #[0.7071067811865475] #[0] #[0]])
```
Now that looks same as qiskit. So how can we make it easier to combine these gates? Lets write some utility functions.

```racket
(define (G* . ms)  ;; qiskit compatible
  (apply-op (apply t* (reverse ms))))

(define (nG* . ms) ;; native order
  (apply-op (apply t* ms)))

(define (qubits n)
  (apply t* (for/list ([i (range n)])
              q0)))
```

If we don't like little endian order, we can switch to normal order by using `nG*` function instead of `G*`. The `qubits` function just creates a state vector of n qubits all set to `|0>`.

And finally we have a function to compose gates to create a circuit!

```racket
(define (make-circuit matrices #:assembler [assembler G*])
  (let ([ops (map (λ (gs) (if (list? gs)
                              (apply assembler gs)
                              (apply-op gs)))
                  matrices)])
    (λ (input-qbits)
      (for/fold ([sv input-qbits])
                ([f ops])
        (f sv)))))
```

And we are done! Indeed, with just about these, we are now ready to create some circuits and experiment.

## Part 4 - Simple Circuits

We will experiment with some basic circuits in this part before moving on to something complicated. We will see the diagrams drawn from Qiskit programs. Lets start with some Hadamard gates.

<img width="214" alt="circuit_3_1" src="https://github.com/souravdatta/qsym/assets/1576318/d3609b84-a70d-4f1a-8af4-78c3ac4271ed">

The qiskit code for this is:

```Python
circuit = QuantumCircuit(2)

circuit.x(1)
circuit.barrier()
circuit.h(0)
circuit.h(1)

circuit.draw('mpl')
```

And this is how it looks like in qsym

```Racket
(define c1 (make-circuit
            (list (list (I 2)
                        X)
                  (list H
                        H))))
```

You can see in our code we need to explicitly specify all the gates for a layer. In Qiskit, we can say just apply `X` to qubit 1 and leave qubit 0 alone. We cannot do this currently in qsym because we create the layers based on just matrix multiplications. Since there is nothing applied at this stage to qubit 0, we need to say apply an `2x2 identity matrix` to the first one, which will keep it unchanged. Now, internally qiskit might also be doing it, but our case is, at least for now, very explicit. Similarly in the second layer we apply two Hadamard gates to both qubit 0 and 1. Lets see the output of this circuit after measuring. The qiskit code:

```Python
sim2 = QasmSimulator()
circuit.measure_all()
result = sim2.run(circuit).result()
counts = result.get_counts()
```
And equivalent qsym code:

```Racket
(counts (c1 (qubits 2)))
```

Since our circuits are just plain functions, we apply to it a combination of 2 qubits all in base state. Then we use `counts` to measure and tally the counts for 1024 runs.

```
'#hash(((0 1) . 255) ((0 0) . 272) ((1 1) . 252) ((1 0) . 245))
```
We see almost equal probabilities for getting all possible combinations. The output is same as in qiskit.

<img width="467" alt="circuit_3_2" src="https://github.com/souravdatta/qsym/assets/1576318/523ba42f-9aa8-4195-9c48-5fe92657fee1">

Now lets do another circuit with 3 qubits.

<img width="230" alt="circuit_3_3" src="https://github.com/souravdatta/qsym/assets/1576318/be20e851-649c-438e-a722-1efc5e920672">

The code for this is:

```Racket
(define c2 (make-circuit
            (list (list X
                        (I 2)
                        X)
                  (list H
                        (I 2)
                        (I 2)))))
```

And we to measurements with:

```Racket
(counts (c2 (qubits 3)))
```

Note, now our input is superposition of 3 qubits in base state.

Output:
```
'#hash(((1 0 0) . 511) ((1 0 1) . 513))
```

#### The CNOT gate
We can't go far without using controlled gates - gates which control their output qubit based on a control qubit. A typical control gate is the CNOT gate, which looks like this:

<img width="122" alt="cnot_3_4" src="https://github.com/souravdatta/qsym/assets/1576318/f1b11c78-35cd-4152-aaba-624f4c00177e">

When `q0` is `|1>`, then `q1` is flipped. `q0` continues be the same on the output side. When `q0` is `|0>` then the outputs are unchanged.

How do we build a gate like this in our library? The answer is simple really, we just need to find the unitary matrix corresponding to this gate. Lets see how we do that.

First, we create the truth table for the gate.

```
  q1     |     q0     |    o1      |    o2

  0            0           0            0
  0            1           1            1          <-- flipped
  1            0           1            0
  1            1           0            1          <-- flipped
```
  
Looking at the outputs we now know that for a given input, which column of the matrix needs to be on in order for that qubit combination to be selected. Essentially, this happens by converting the above truth table in the column vector form.

```
|0 0>
[1,            [1,
 0,      ===>   0,
 0,             0,
 0]             0]

|0 1>
[0,           [0,
 1,      ===>  0,
 0,            0, 
 0]            1]

|1 0>
[0,           [0,
 0,      ===>  0,
 1,            1, 
 0]            0]

|1 1>
[0,           [0,
 0,      ===>  1,
 0,            0, 
 1]            0]

```
Since its a superposition of 2 qubits, we need 4 rows in the column vector form. 

Second, we combine the column vectors in the output and put them in a matrix. So, here's our CNOT matrix in final form.

```
#[#[1 0 0 0]
  #[0 0 0 1]
  #[0 0 1 0]
  #[0 1 0 0]]
```

Ok, but how do we get this matrix just from a function like CNOT? We need to add a few functions. So here goes:

```Racket
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
```
The function `bits->colv` takes a binary string in qubit or bit representation and converts it into its corresponding column vector representation.

```Racket
(define (gate-matrix n tx-rules)
  (let* ([inputs (bits-of-len n)]
         [coords (for/list ([i inputs])
                   (transform-rules (reverse i) ;; msb -> lsb
                                    tx-rules))]
         [lsb-coords (map reverse coords)])
    (matrix-transpose
     (list*->matrix
      (map bits->colv lsb-coords)))))
```

We take a bit length of n and some rules. These rules are of the form:

```
(list-of (list-of indexes) function-on-the-indexes)
```
The list of indexes indicate which of the inputs are to be applied to the function. For the other inputs, it will be copied to output without change. The function is suposed to return the same number of outputs as the inputs. The reason for this will be apparent for circuits where input is 6 qubits but out of those we only connect 0th and 4th qubits to a CNOT gate. The functions which do the transformations of the input to output after applying the transformation rules, are as follows:

```Racket
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
```

Lets see it in action:

```Racket
(define (cnot-f control target)
  (if (= control 1)
      (list control (if (= target 1) 0 1))
      (list control target)))

(define cnot-gate (gate-matrix 2
                               (list (list '(0 1)
                                           cnot-f))))
(define CX cnot-gate)
```

The cnot-gate matrix looks like this:
```
(array #[#[1 0 0 0] #[0 0 0 1] #[0 0 1 0] #[0 1 0 0]])
```
This is same as what we worked out manually. Below is a code to put it into action, we are going to use a Hadamard gate to put the control qubit into all possible states and then check how CNOT gate works against all of those. The circuit we are building is like this:

<img width="172" alt="cnot_3_5" src="https://github.com/souravdatta/qsym/assets/1576318/4187f64b-fb57-4ca4-9c3d-a0259574c152">


```Racket
(define c3 (make-circuit
            (list (list H
                        X)
                  CX)))

(counts (c3 (qubits 2)))
```

Output:
```
'#hash(((0 1) . 493) ((1 0) . 531))
```

For all possible values of the control qubit we see CNOT gate flipping the output. Next we will put Hadamard gate on lowermost control qubit. The output is especially interesting.

<img width="184" alt="cnot_3_6" src="https://github.com/souravdatta/qsym/assets/1576318/83c2cfe5-c649-4c89-9c94-2180a385332b">

Here's the code and output:
```Racket
(define c4 (make-circuit
            (list (list H
                        (I 2))
                  CX)))

(counts (c4 (qubits 2)))
```

```
'#hash(((1 1) . 534) ((0 0) . 490))
```

Here, we get both qubits wither `00` or `11`. However, turns out that with a gate like this the output qubits are **entangled**! Which means, if one qubit is measured `0` then the other will definitely be measured `0` and vice versa! Even when you take one qubit at the end of the galaxy. If that measures as `1`, the one on earth will also measure as `1`! And that's what we also see in the final output. How entanglement works is still a puzzle, no wonder, old Einstein named it Spooky action at a distance. But for us, mere mortal Lisp programmers, I think entangled particles are like code in the form of data! More on that ranting in a blog somewhere else.


