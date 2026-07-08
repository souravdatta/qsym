# Part 8 — Superdense Coding: Two Bits in One Qubit

*Quantum Computing with qsym, a series for developers. Full code:
[github.com/souravdatta/qsym](https://github.com/souravdatta/qsym)*

Teleportation (chapter 7) spent **two classical bits** plus a shared Bell
pair to move **one qubit**. Superdense coding is the exact mirror image:
spend **one qubit** plus a shared Bell pair to move **two classical bits**.
The two protocols are duals — and this one is even shorter to build.

## The idea

Alice and Bob share a Bell pair (made in advance, like last time). Alice
wants to send Bob a two-bit message: 00, 01, 10, or 11.

The trick: there are exactly **four** maximally entangled two-qubit states —
the four *Bell states* — and Alice can steer the shared pair from one to any
other by acting **only on her own qubit**:

| Message | Alice applies | Resulting Bell state |
|---------|--------------|----------------------|
| 00 | nothing | (&#124;00⟩ + &#124;11⟩)/√2 |
| 01 | Z | (&#124;00⟩ − &#124;11⟩)/√2 |
| 10 | X | (&#124;01⟩ + &#124;10⟩)/√2 |
| 11 | Z then X | (&#124;01⟩ − &#124;10⟩)/√2 |

She then mails her single qubit to Bob. Bob, now holding both qubits, runs
the Bell-pair circuit **in reverse** (CX then H — remember from chapter 3
that every circuit has an inverse), which maps each Bell state to a distinct
plain basis state. He measures and reads both bits.

## The code

```racket
#lang racket
(require qsym)

;; Build the whole story as one circuit, parameterized by the message.
;; Qubit 0 = Alice's half, qubit 1 = Bob's half.
(define (superdense b1 b0)
  (make-circuit
   (append
    ;; Shared Bell pair
    (list (list H ID) CX)
    ;; Alice encodes her two bits on HER qubit only
    (if (= b0 1) (list (list Z ID)) '())
    (if (= b1 1) (list (list X ID)) '())
    ;; ...Alice's qubit travels to Bob...
    ;; Bob decodes: un-does the Bell circuit, then measures
    (list CX
          (list H ID)
          (measure 0 1)))
   #:clbits 2))

(for* ([b1 '(0 1)] [b0 '(0 1)])
  (define c (run-shots (superdense b1 b0) (qubits 2) #:shots 200 #:seed 1))
  (displayln (format "send (~a,~a) → Bob reads ~a" b1 b0 (hash-keys c))))
```

Output:

```
send (0,0) → Bob reads (00)
send (0,1) → Bob reads (01)
send (1,0) → Bob reads (10)
send (1,1) → Bob reads (11)
```

Every message decodes perfectly — 200 shots each, a single outcome every
time. No statistics, no error rate: the four Bell states are perfectly
distinguishable *once you hold both qubits*.

## Why this doesn't violate information theory

A lone qubit can only ever yield one classical bit of information (a
measurement has two outcomes — that's Holevo's bound). Superdense coding
doesn't beat that: **two** qubits crossed the channel in total — Bob's half
earlier, Alice's half now. The magic is in the *timing*: Bob's half was sent
before Alice had even decided on her message. Entanglement let them
pre-position half the bandwidth.

Notice also what an eavesdropper gets by grabbing Alice's qubit in transit:
nothing. Alone, her qubit is maximally mixed (Bloch vector at the center —
chapter 5), identical for all four messages. The message only exists in the
pair.

## The duality, side by side

| | Teleportation | Superdense coding |
|---|---|---|
| Pre-shared | 1 Bell pair | 1 Bell pair |
| Sent | 2 classical bits | 1 qubit |
| Delivered | 1 qubit | 2 classical bits |

**Next time:** our first real quantum *algorithm*. Deutsch–Jozsa answers in
one query a question that classically takes up to 2ⁿ⁻¹ + 1 lookups.
