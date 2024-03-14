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
How do we show a classical bit? Its easy, either write `0` or `1`. That's because a bit can either be in state `0` or `1`. In hardware, this could be that a 5 volt charge can represent 1 and 0 volt can represent 0. Current hardware and SSD disks are much advanced, but the basic concept is the same. What about two bits? Two bits can be in various different combinations of states, because if one is `0` the other can be either `0` or `1` abd vice versa. So, these are possible states: `00`, `01`, `10`, `11`. In a little math terms, if we have `n` bits, there can be `2^n` combinations in total. This is good, but we can represent the same thing with a little different manner, which will be very useful when we go to qubits. This representation does not list out all the combinations individually, but rather shows which value among all combinations should be turned on. Lets look at it in action. For `n = 2`, we know that we will have `2^2 = 4` combinations, which we saw earlier. This means if I create a list of 4 elements, I can map an element in the list to one of the combinations. A list like `[a, b, c, d]` can be used to map like this: `a => 00, b => 01, c => 10, d => 11`. But since, at any moment, only one of these 4 combinations can be present, it means out of `a, b, c and d` only one value can be present at a time, but not all. So then simplifying the mapping a bit. We say, `[1, 0, 0, 0]` means `00`. Similarly, `[0, 1, 0, 0]` means `01`; `[0, 0, 1, 0]` means `10`; `[0, 0, 0, 1]` means `11`. 








