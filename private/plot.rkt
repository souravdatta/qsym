#lang racket/base

;; Histogram and state-probability plots via Racket's plot library.

(require plot
         racket/list
         "linalg.rkt"
         "state.rkt")

(provide plot-histogram
         plot-state-probabilities)

;; plot-histogram: hash? [string?] -> renderer
;; Render a counts hash as a discrete histogram sorted by bit-string label.
;; Returns the plot renderer result (works in DrRacket; save with plot-file).
(define (plot-histogram counts [title "Measurement counts"])
  (define labels (sort (hash-keys counts) string<?))
  (define total  (for/sum ([v (in-hash-values counts)]) v))
  (define data
    (for/list ([lbl labels])
      (vector lbl (/ (hash-ref counts lbl 0) (max 1 total)))))
  (plot (discrete-histogram data #:label "probability" #:color 3)
        #:title  title
        #:x-label "Outcome"
        #:y-label "Probability"
        #:y-min 0 #:y-max 1))

;; plot-state-probabilities: quantum-state? [string?] -> renderer
;; Plot the exact |amplitude|² distribution for every basis state.
(define (plot-state-probabilities state [title "State probabilities"])
  (define n    (quantum-state-num-qubits state))
  (define amps (quantum-state-amplitudes state))
  (define data
    (for/list ([i (in-range (expt 2 n))])
      (define m (magnitude (vector-ref amps i)))
      (vector (index->bit-string n i) (* m m))))
  (plot (discrete-histogram data #:label "probability" #:color 3)
        #:title   title
        #:x-label "Basis state"
        #:y-label "Probability"
        #:y-min 0 #:y-max 1))
