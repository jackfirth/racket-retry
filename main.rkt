#lang racket/base

(require racket/contract/base)

(provide
 with-retry
 (contract-out
  [call/retry (-> retryer? (-> any) any)]
  [immediate-retryer retryer?]
  [limit-retryer (-> exact-nonnegative-integer? retryer?)]
  [print-retryer
   (-> (-> string? exact-nonnegative-integer? void?) retryer?)]
  [restrict-thrown-retryer (-> (-> any/c boolean?) retryer?)]
  [retryer (-> (-> any/c exact-nonnegative-integer? void?)
               (-> any/c boolean?)
               retryer?)]
  [retryer? predicate/c]
  [retryer-compose (->* () #:rest (listof retryer?) retryer?)]
  [retryer-handle (-> retryer? any/c exact-nonnegative-integer? void?)]
  [retryer-should-retry? (-> retryer? exact-nonnegative-integer? boolean?)]
  [sleep-quadratic-retryer
   (->* (exact-nonnegative-integer?)
        (#:reset-after exact-nonnegative-integer?)
        retryer?)]
  [sleep-random-retryer (-> exact-positive-integer? retryer?)]
  [sleep-retryer (-> exact-nonnegative-integer? retryer?)]))

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

(define (print-retryer printer)
  (retryer (λ (thrown num-previous-retries)
             (unless (exn? thrown) (raise thrown))
             (printer (exn-message thrown) num-previous-retries))
           (const #t)))

(define (sleep-random-retryer max-milliseconds)
  (retryer (thunk* (sleep (/ (random max-milliseconds) 1000))) (const #t)))

(define (sleep-retryer milliseconds)
  (retryer (thunk* (sleep (/ milliseconds 1000))) (const #t)))

(define (sleep-quadratic-retryer milliseconds
                                 #:reset-after [reset-after #f])
  (retryer (λ (_ num-previous-retries)
             (define num-previous/reset
               (if reset-after
                   (modulo num-previous-retries reset-after)
                   num-previous-retries))
             (sleep (/ (* (add1 num-previous/reset) milliseconds) 1000)))
           (const #t)))

(define (restrict-thrown-retryer should-handle?)
  (retryer (λ (thrown _) (unless (should-handle? thrown) (raise thrown)))
           (const #t)))

(define (limit-retryer max-retries) (retryer void (λ (n) (< n max-retries))))

(define (retryer-compose . retryers)
  (define retryers/compose-order (reverse retryers))
  (define (handle/compose thrown num-previous-retries)
    (for ([retryer (in-list retryers/compose-order)])
      (retryer-handle retryer thrown num-previous-retries)))
  (define (should-retry?/compose num-previous-retries)
    (andmap (λ (retryer) (retryer-should-retry? retryer num-previous-retries))
            retryers/compose-order))
  (retryer handle/compose should-retry?/compose))
