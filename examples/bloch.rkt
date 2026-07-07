#lang racket

;; Bloch sphere demo: single-qubit states and the effect of entanglement.
;; Saves a PNG with four spheres: |0⟩, |+⟩, Rx(π/3)|0⟩, and one half of a
;; Bell pair (maximally mixed — the vector shrinks to the center).

(require qsym
         pict
         racket/draw)

(define bell
  ((make-circuit (list (list H ID) (at CX 0 1)) #:qubits 2) (qubits 2)))

(define row
  (hc-append 16
             (bloch-pict q0)                    ; north pole
             (bloch-pict (gH q0))               ; +x axis
             (bloch-pict (gRx (/ pi 3) q0))     ; tilted in the y-z plane
             (bloch-pict bell 0)))              ; entangled: |r| = 0

(displayln "Bloch vectors:")
(displayln (format "  |0>          : ~a" (bloch-vector q0 0)))
(displayln (format "  |+>          : ~a" (bloch-vector (gH q0) 0)))
(displayln (format "  Rx(pi/3)|0>  : ~a" (bloch-vector (gRx (/ pi 3) q0) 0)))
(displayln (format "  Bell qubit 0 : ~a" (bloch-vector bell 0)))

(define out "bloch.png")
(send (pict->bitmap row) save-file out 'png)
(displayln (format "\nSaved diagram to ~a" out))

;; All qubits of a GHZ state at once — every qubit is maximally mixed.
(define ghz
  ((make-circuit (list (list H ID ID) (at CX 0 1) (at CX 0 2)) #:qubits 3)
   (qubits 3)))
(displayln (format "GHZ qubit vectors: ~a"
                   (for/list ([q (in-range 3)]) (bloch-vector ghz q))))
