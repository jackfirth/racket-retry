#lang racket/base

(require racket/contract/base)

(provide
 with-retry
 (contract-out
  [call/retry (-> retryer? (-> any) any)]
  [retryer (->* ()
                (#:should-retry? (-> any/c boolean?)
                 #:handle (-> any/c exact-nonnegative-integer? void?))
                retryer?)]
  [retryer? predicate/c]
  [retryer-handle (-> retryer? any/c exact-nonnegative-integer? void?)]
  [retryer-should-retry? (-> retryer? any/c exact-nonnegative-integer? boolean?)]))

(require racket/function
         syntax/parse/define)


(struct retryer (should-retry-proc handle-proc)
  #:omit-define-syntaxes
  #:constructor-name make-retryer)

(define (retryer #:should-retry? [should-retry (const #t)]
                 #:handle [handle void])
  (make-retryer should-retry handle))

(define (retryer-handle retryer raised num-previous-retries)
  ((retryer-handle-proc retryer) raised num-previous-retries))

(define (retryer-should-retry? retryer raised num-previous-retries)
  ((retryer-should-retry-proc retryer) raised num-previous-retries))

(define (call/retry retryer proc)
  (let loop ([num-previous-retries 0])
    (define (handle raised)
      (if (retryer-should-retry? retryer raised num-previous-retries)
          (begin
            (retryer-handle retryer raised num-previous-retries)
            (loop (add1 num-previous-retries)))
          (raise raised)))
    (with-handlers ([(const #t) handle]) (proc))))

(define-simple-macro (with-retry retryer-expr:expr body:expr ...)
  (call/retry retryer-expr (λ () body ...)))
