# Building a Quantum Simulator from scratch

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
```
A qubit can be either in |0> state or |1> state, or any state in between. This is called superposition state of the qubit.
```
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
Where, the probability formula for `a` and `b` is `a^2 + b^2 = 1`. Here `a` and `b` are `complex` numbers. And the weird thing is, a until we measure a qubit, it can be in a superposition state; but as soon as we measure the qubit, it collapses into one of `|0>` or `|1>` states! (Insert your favorite quote from Richard Fyenman about quantum weirdness here)

The third from above is the general way we represent a qubit. As we can see, if b = 0 then we get `|0>` and if a = 0 we get `|1>`. This is what differentiates a classical bit's column vector from a qubit's column vector. In classical bits, the column vector can never have anything other than 1 in the rows. And that too only one of the rows can be `1` at a time. For qubits it can be any complex numbers at any row of the column vector, as long they all when squared and summed make 1.

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

#### Measuring qubits
Before we get down to measure bits, what's a measurement? As we go into the quantum domain, measurement becomes an important thing be watchful of. In simple terms, measurement is a process of observing the bits. And, it can be done either by a human directly or by a machine - either with light or with any other means. Before we measure something, the state of the system is unknown to us, but after we measure it it becomes known - which is stupidly simple but sort of becomes an interesting thing in the quantum domain. 








