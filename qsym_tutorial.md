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

