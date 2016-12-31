#lang racket/base

(require racket/contract/base)

(provide
 (contract-out
  [current-sleep (parameter/c sleep/c)]
  [current-random (parameter/c random/c)]
  [sleep* sleep/c]
  [random* random/c]))

(define sleep/c (-> (>=/c 0) void?))
(define random/c (-> (integer-in 1 4294967087) exact-nonnegative-integer?))

(define current-sleep (make-parameter sleep))
(define (sleep* amount) ((current-sleep) amount))
(define current-random (make-parameter random))
(define (random* max) ((current-random) max))
