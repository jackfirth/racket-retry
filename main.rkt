#lang racket/base

(require racket/contract/base)

(provide
 with-retry
 (contract-out
  [retryer? predicate/c]
  [immediate-logging-retryer retryer?]
  [call/retry (-> retryer? (-> any) any)]
  [retryer-handle (-> retryer? any/c exact-nonnegative-integer? void?)]
  [retryer-should-retry? (-> retryer? exact-nonnegative-integer? boolean?)]))

(require racket/function
         syntax/parse/define)


(struct retryer (handle-proc should-retry-proc))

(define (num-times-text num-previous-times)
  (format (if (zero? num-previous-times) "~a time" "~a times")
          (add1 num-previous-times)))

(define immediate-retryer (retryer void (const #t)))

(define immediate-logging-retryer
  (retryer (λ (thrown num-previous-retries)
             (unless (exn? thrown) (raise thrown))
             (printf "Failed ~a, message: ~a\n"
                     (num-times-text num-previous-retries)
                     (exn-message thrown)))
           (const #t)))

(define (retryer-handle retryer thrown num-previous-retries)
  ((retryer-handle-proc retryer) thrown num-previous-retries))

(define (retryer-should-retry? retryer num-previous-retries)
  ((retryer-should-retry-proc retryer) num-previous-retries))

(define (call/retry retryer thunk)
  (let loop ([num-previous-retries 0])
    (define (handle thrown)
      (retryer-handle retryer thrown num-previous-retries)
      (if (retryer-should-retry? retryer num-previous-retries)
          (loop (add1 num-previous-retries))
          (raise thrown)))
    (with-handlers ([(const #t) handle]) (thunk))))

(define-simple-macro (with-retry retryer-expr:expr body:expr ...)
  (call/retry retryer-expr (λ () body ...)))
