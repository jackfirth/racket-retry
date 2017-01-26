#lang racket/base

(require racket/contract/base)

(provide
 with-retry
 (contract-out
  [call/retry (-> retryer? (-> any) any)]
  [retryer (->* ()
                (#:should-retry? (-> any/c exact-nonnegative-integer? boolean?)
                 #:handle (-> any/c exact-nonnegative-integer? void?))
                retryer?)]
  [retryer? predicate/c]
  [retryer-handle (-> retryer? any/c exact-nonnegative-integer? void?)]
  [retryer-should-retry? (-> retryer? any/c exact-nonnegative-integer? boolean?)]))

(require racket/function
         syntax/parse/define)

(module+ test
  (require mock
           mock/rackunit
           rackunit))


(struct retryer (should-retry-proc handle-proc)
  #:omit-define-syntaxes
  #:constructor-name make-retryer)

(define (retryer #:should-retry? [should-retry (const #t)]
                 #:handle [handle void])
  (make-retryer should-retry handle))

(define (retryer-handle ret raised num-previous-retries)
  ((retryer-handle-proc ret) raised num-previous-retries))

(define (retryer-should-retry? ret raised num-previous-retries)
  ((retryer-should-retry-proc ret) raised num-previous-retries))

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

(module+ test
  (define (foo? v) (equal? v 'foo))
  (define test-history (call-history))
  (define should-retry-mock
    (mock #:name 'should-retry-mock
          #:behavior (const-series #t #t #f)
          #:external-histories (list test-history)))
  (define handle-mock
    (mock #:name 'handle-mock
          #:behavior void
          #:external-histories (list test-history)))
  (define mock-retryer
    (retryer #:should-retry? should-retry-mock #:handle handle-mock))
  (check-exn foo? (thunk (with-retry mock-retryer (raise 'foo))))
  (check-call-history-names
   test-history
   (list 'should-retry-mock 'handle-mock
         'should-retry-mock 'handle-mock
         'should-retry-mock))
  (check-mock-calls should-retry-mock
                    (list (arguments 'foo 0)
                          (arguments 'foo 1)
                          (arguments 'foo 2)))
  (check-mock-calls handle-mock
                    (list (arguments 'foo 0)
                          (arguments 'foo 1))))
