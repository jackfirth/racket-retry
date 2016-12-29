#lang racket/base

(require racket/contract/base)

(provide
 (contract-out
  [cycle-retryer (-> retryer? exact-positive-integer? retryer?)]
  [retryer-compose (->* () #:rest (listof retryer?) retryer?)]))

(require fancy-app
         "base.rkt")


(define (retryer-compose . retryers)
  (define retryers/compose-order (reverse retryers))
  (define (handle/compose thrown num-previous-retries)
    (for ([retryer (in-list retryers/compose-order)])
      (retryer-handle retryer thrown num-previous-retries)))
  (define (should-retry?/compose thrown num-previous-retries)
    (andmap (retryer-should-retry? _ thrown num-previous-retries)
            retryers/compose-order))
  (retryer #:should-retry? should-retry?/compose #:handle handle/compose))

(define (cycle-retryer base cycle-length)
  (define ((wrap/cycle proc) thrown num-previous-retries)
    (proc thrown (modulo num-previous-retries cycle-length)))
  (retryer #:should-retry? (wrap/cycle (retryer-should-retry? base _ _))
           #:handle (wrap/cycle (retryer-handle base _ _))))
