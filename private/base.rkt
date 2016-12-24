#lang racket/base

(require racket/contract/base)

(provide
 with-retry
 (contract-out
  [call/retry (-> retryer? (-> any) any)]
  [cycle-retryer (-> retryer? exact-positive-integer? retryer?)]
  [immediate-retryer retryer?]
  [retryer (-> (-> any/c exact-nonnegative-integer? void?)
               (-> any/c boolean?)
               retryer?)]
  [retryer? predicate/c]
  [retryer-compose (->* () #:rest (listof retryer?) retryer?)]
  [retryer-handle (-> retryer? any/c exact-nonnegative-integer? void?)]
  [retryer-should-retry? (-> retryer? exact-nonnegative-integer? boolean?)]))

(require racket/function
         syntax/parse/define)


(struct retryer (handle-proc should-retry-proc))

(define (retryer-handle retryer thrown num-previous-retries)
  ((retryer-handle-proc retryer) thrown num-previous-retries))

(define (retryer-should-retry? retryer num-previous-retries)
  ((retryer-should-retry-proc retryer) num-previous-retries))

(define (call/retry retryer thunk)
  (let loop ([num-previous-retries 0])
    (define (handle thrown)
      (if (retryer-should-retry? retryer num-previous-retries)
          (begin
            (retryer-handle retryer thrown num-previous-retries)
            (loop (add1 num-previous-retries)))
          (raise thrown)))
    (with-handlers ([(const #t) handle]) (thunk))))

(define-simple-macro (with-retry retryer-expr:expr body:expr ...)
  (call/retry retryer-expr (λ () body ...)))

(define immediate-retryer (retryer void (const #t)))

(define (retryer-compose . retryers)
  (define retryers/compose-order (reverse retryers))
  (define (handle/compose thrown num-previous-retries)
    (for ([retryer (in-list retryers/compose-order)])
      (retryer-handle retryer thrown num-previous-retries)))
  (define (should-retry?/compose num-previous-retries)
    (andmap (λ (retryer) (retryer-should-retry? retryer num-previous-retries))
            retryers/compose-order))
  (retryer handle/compose should-retry?/compose))

(define (cycle-retryer base-retryer cycle-length)
  (retryer (λ (thrown num-previous-retries)
             (define cycle-retries (modulo num-previous-retries cycle-length))
             (retryer-handle base-retryer thrown cycle-retries))
           (λ (num-previous-retries)
             (retryer-should-retry? base-retryer num-previous-retries))))
