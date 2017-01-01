#lang racket/base

(require racket/contract/base)

(provide
 (contract-out
  [always-retryer retryer?]
  [never-retryer retryer?]
  [limit-retryer (-> exact-nonnegative-integer? retryer?)]
  [print-exn-retryer
   (-> (-> string? exact-nonnegative-integer? string?) retryer?)]
  [sleep-retryer (-> sleep-amount-proc/c retryer?)]
  [sleep-retryer/random (-> sleep-amount-proc/c retryer?)]
  [sleep-const-retryer (-> time-period? retryer?)]
  [sleep-const-retryer/random (-> time-period? retryer?)]
  [sleep-exponential-retryer sleep-exponential-retryer/c]
  [sleep-exponential-retryer/random sleep-exponential-retryer/c]))

(require compose-app/fancy-app
         gregor
         gregor/period
         mock
         racket/function
         "base.rkt"
         "gregor.rkt"
         "inject.rkt")

(module+ test
  (require mock/rackunit
           rackunit))


(define sleep-amount-proc/c
  (-> exact-nonnegative-integer? time-period?))

(define sleep-exponential-retryer/c
  (->* (time-period?)
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

(define (sleep-retryer sleep-period-proc)
  (define (handle/sleep _ num-previous-retries)
    (sleep*
     (time-period->unit (sleep-period-proc num-previous-retries) 'seconds)))
  (retryer #:handle handle/sleep))

(module+ test
  (test-case "sleep-retryer"
    (define sleep-mock (mock #:behavior void))
    (parameterize ([current-sleep sleep-mock])
      (define test-sleep-amount minutes)
      (define test-retryer (sleep-retryer test-sleep-amount))
      (check-true (retryer-should-retry? test-retryer 'foo 5))
      (check-equal? (retryer-handle test-retryer 'foo 5) (void))
      (check-mock-called-with? sleep-mock (arguments 300)))))

(define (sleep-retryer/random max-sleep-amount)
  (sleep-retryer (random-period .. max-sleep-amount)))

(define (sleep-exponential-retryer sleep-period #:exponent-base [base 2])
  (sleep-retryer (*period sleep-period _ .. expt base _)))

(define (sleep-exponential-retryer/random sleep-period #:exponent-base [base 2])
  (sleep-retryer/random (*period sleep-period _ .. expt base _)))

(module+ test
  (test-case "sleep-exponential-retryer/random"
    (define sleep-mock (mock #:behavior void))
    (define random-mock (mock #:behavior sub1))
    (parameterize ([current-sleep sleep-mock] [current-random random-mock])
      (define test-retryer
        (sleep-exponential-retryer/random (seconds 2) #:exponent-base 3))
      (check-true (retryer-should-retry? test-retryer 'foo 12))
      (retryer-handle test-retryer 'foo 0)
      (retryer-handle test-retryer 'foo 1)
      (retryer-handle test-retryer 'foo 2)
      (check-mock-calls sleep-mock
                        (list (arguments 1) (arguments 5) (arguments 17))))))

(define sleep-const-retryer (sleep-retryer .. const))
(define sleep-const-retryer/random (sleep-retryer/random .. const))
