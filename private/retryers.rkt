#lang racket/base

(require racket/contract/base)

(provide
 with-retry
 (contract-out
  [limit-retryer (-> exact-nonnegative-integer? retryer?)]
  [print-exn-retryer
   (-> (-> string? exact-nonnegative-integer? void?) retryer?)]
  [restrict-thrown-retryer (-> (-> any/c boolean?) retryer?)]
  [sleep-retryer
   (-> (-> exact-nonnegative-integer? exact-nonnegative-integer?) retryer?)]
  [sleep-retryer/random
   (-> (-> exact-nonnegative-integer? exact-nonnegative-integer?) retryer?)]
  [sleep-exponential-retryer
   (->* (exact-nonnegative-integer?)
        (#:exponent-base exact-positive-integer?)
        retryer?)]
  [sleep-exponential-retryer/random
   (->* (exact-nonnegative-integer?)
        (#:exponent-base exact-positive-integer?)
        retryer?)]))

(require racket/function
         syntax/parse/define
         "base.rkt")


(define (limit-retryer max-retries) (retryer void (λ (n) (< n max-retries))))

(define (print-exn-retryer printer)
  (retryer (λ (thrown num-previous-retries)
             (unless (exn? thrown) (raise thrown))
             (printer (exn-message thrown) num-previous-retries))
           (const #t)))

(define (restrict-thrown-retryer should-handle?)
  (retryer (λ (thrown _) (unless (should-handle? thrown) (raise thrown)))
           (const #t)))

(define (sleep-retryer sleep-amount)
  (retryer (λ (_ num-previous-retries)
             (sleep (sleep-amount num-previous-retries)))
           (const #t)))

(define (sleep-retryer/random max-sleep-amount)
  (sleep-retryer (compose random max-sleep-amount)))

(define (sleep-exponential-retryer milliseconds #:exponent-base [base 2])
  (sleep-retryer (λ (num-previous-retries)
                   (/ (* (expt base num-previous-retries) milliseconds) 1000))))

(define (sleep-exponential-retryer/random milliseconds #:exponent-base [base 2])
  (sleep-retryer (λ (num-previous-retries)
                   (/ (* (expt base num-previous-retries) milliseconds) 1000))))
