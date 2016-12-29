#lang racket/base

(require racket/contract/base)

(provide
 with-retry
 (contract-out
  [always-retryer retryer?]
  [never-retryer retryer?]
  [limit-retryer (-> exact-nonnegative-integer? retryer?)]
  [print-exn-retryer
   (-> (-> string? exact-nonnegative-integer? void?) retryer?)]
  [sleep-retryer (-> sleep-amount-proc/c retryer?)]
  [sleep-retryer/random (-> sleep-amount-proc/c retryer?)]
  [sleep-exponential-retryer sleep-exponential-retryer/c]
  [sleep-exponential-retryer/random sleep-exponential-retryer/c]))

(require compose-app/fancy-app
         mock
         racket/function
         "base.rkt")

(module+ test
  (require mock/rackunit
           rackunit))


(define sleep-amount-proc/c
  (-> exact-nonnegative-integer? exact-nonnegative-integer?))

(define sleep-exponential-retryer/c
  (->* (exact-nonnegative-integer?)
       (#:exponent-base exact-positive-integer?)
       retryer?))

(define always-retryer (retryer))
(define never-retryer (retryer #:should-retry? (const #f)))

(module+ test
  (check-true (retryer-should-retry? always-retryer 'foo 12))
  (check-false (retryer-should-retry? never-retryer 'foo 12))
  (check-equal? (retryer-handle always-retryer 'foo 12) (void))
  (check-equal? (retryer-handle never-retryer 'foo 12) (void)))

(define (limit-retryer max-retries)
  (retryer #:should-retry? (λ (thrown n) (< n max-retries))))

(module+ test
  (define limit10-retryer (limit-retryer 10))
  (check-true (retryer-should-retry? limit10-retryer 'foo 4))
  (check-false (retryer-should-retry? limit10-retryer 'foo 14))
  (check-equal? (retryer-handle limit10-retryer 'foo 4) (void)))

(define/mock (print-exn-retryer message-proc)
  #:mock displayln #:as displayln-mock #:with-behavior void
  (define (handle/print raised-exn num-previous-retries)
    (displayln (message-proc (exn-message raised-exn) num-previous-retries)))
  (define (should-retry?/print raised _) (exn? raised))
  (retryer #:should-retry? should-retry?/print #:handle handle/print))

(module+ test
  (with-mocks print-exn-retryer
    (define test-message
      (format "Received exn-message: ~a and num-previous-retries: ~a" _ _))
    (define test-retryer (print-exn-retryer test-message))
    (define test-exn (make-exn "test exception" (current-continuation-marks)))
    (check-true (retryer-should-retry? test-retryer test-exn 12))
    (check-false (retryer-should-retry? test-retryer 'foo 12))
    (check-equal? (retryer-handle test-retryer test-exn 12) (void))
    (define expected-displayln-arguments
      (arguments
       "Received exn-message: test exception and num-previous-retries: 12"))
    (check-mock-called-with? displayln-mock expected-displayln-arguments)))

(define (sleep-retryer sleep-amount)
  (retryer #:handle (λ (_ num-previous-retries)
                      (sleep (sleep-amount num-previous-retries)))))

(define (sleep-retryer/random max-sleep-amount)
  (sleep-retryer (random .. max-sleep-amount)))

(define (sleep-exponential-retryer milliseconds #:exponent-base [base 2])
  (sleep-retryer (/ _ 1000 .. * _ milliseconds .. expt base _)))

(define (sleep-exponential-retryer/random milliseconds #:exponent-base [base 2])
  (sleep-retryer (/ _ 1000 .. * _ milliseconds .. expt base _)))
