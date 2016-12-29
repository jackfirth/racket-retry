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
         racket/function
         syntax/parse/define
         "base.rkt")


(define sleep-amount-proc/c
  (-> exact-nonnegative-integer? exact-nonnegative-integer?))

(define sleep-exponential-retryer/c
  (->* (exact-nonnegative-integer?)
       (#:exponent-base exact-positive-integer?)
       retryer?))

(define always-retryer (retryer))
(define never-retryer (retryer #:should-retry? (const #f)))

(define (limit-retryer max-retries) (retryer #:should-retry? (< _ max-retries)))

(define (print-exn-retryer printer)
  (retryer #:handle (λ (raised num-previous-retries)
                      (unless (exn? raised) (raise raised))
                      (printer (exn-message raised) num-previous-retries))))

(define (sleep-retryer sleep-amount)
  (retryer #:handle (λ (_ num-previous-retries)
                      (sleep (sleep-amount num-previous-retries)))))

(define (sleep-retryer/random max-sleep-amount)
  (sleep-retryer (random .. max-sleep-amount)))

(define (sleep-exponential-retryer milliseconds #:exponent-base [base 2])
  (sleep-retryer (/ _ 1000 .. * _ milliseconds .. expt base _)))

(define (sleep-exponential-retryer/random milliseconds #:exponent-base [base 2])
  (sleep-retryer (/ _ 1000 .. * _ milliseconds .. expt base _)))
