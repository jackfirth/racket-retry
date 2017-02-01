#lang racket/base

(require racket/contract/base)

(provide
 (contract-out
  [cycle-retryer (-> retryer? exact-positive-integer? retryer?)]
  [retryer-compose (->* () #:rest (listof retryer?) retryer?)]))

(require fancy-app
         "base.rkt")

(module+ test
  (require mock
           mock/rackunit
           racket/function
           rackunit))


(define (retryer-compose . retryers)
  (define retryers/compose-order (reverse retryers))
  (define (handle/compose thrown num-previous-retries)
    (for ([retryer (in-list retryers/compose-order)])
      (retryer-handle retryer thrown num-previous-retries)))
  (define (should-retry?/compose thrown num-previous-retries)
    (andmap (retryer-should-retry? _ thrown num-previous-retries)
            retryers/compose-order))
  (retryer #:should-retry? should-retry?/compose #:handle handle/compose))

(module+ test
  (test-case "retryer-compose"
    (define history (call-history))
    (define (handle-mock name)
      (mock #:behavior void #:name name #:external-histories (list history)))
    (define handle-mock1 (handle-mock 'handle-mock1))
    (define handle-mock2 (handle-mock 'handle-mock2))
    (define (reset!)
      (mock-reset! handle-mock1)
      (mock-reset! handle-mock2)
      (call-history-reset! history))
    (define (compose/mocks first-should-retry? second-should-retry?)
      (retryer-compose (retryer #:should-retry? (const first-should-retry?)
                                #:handle handle-mock1)
                       (retryer #:should-retry? (const second-should-retry?)
                                #:handle handle-mock2)))
    (test-case "both handle"
      (define both-retryer (compose/mocks #t #t))
      (check-true (retryer-should-retry? both-retryer 'foo 12))
      (check-pred void? (retryer-handle both-retryer 'foo 12))
      (check-call-history-names history (list 'handle-mock2 'handle-mock1))
      (check-mock-called-with? handle-mock1 (arguments 'foo 12))
      (check-mock-called-with? handle-mock2 (arguments 'foo 12))
      (reset!))
    (test-case "first handle"
      (define first-retryer (compose/mocks #t #f))
      (check-false (retryer-should-retry? first-retryer 'foo 12))
      (reset!))
    (test-case "second handle"
      (define second-retryer (compose/mocks #f #t))
      (check-false (retryer-should-retry? second-retryer 'foo 12))
      (reset!))))

(define (cycle-retryer base cycle-length)
  (define ((wrap/cycle proc) thrown num-previous-retries)
    (proc thrown (modulo num-previous-retries cycle-length)))
  (retryer #:should-retry? (wrap/cycle (retryer-should-retry? base _ _))
           #:handle (wrap/cycle (retryer-handle base _ _))))

(module+ test
  (test-case "cycle-retryer"
    (define should-retry-mock
      (mock #:name 'should-retry-mock #:behavior (const #t)))
    (define handle-mock (mock #:name 'handle-mock #:behavior void))
    (define retryer-mock
      (retryer #:should-retry? should-retry-mock #:handle handle-mock))
    (define cyclic-retryer (cycle-retryer retryer-mock 10))
    (check-true (retryer-should-retry? cyclic-retryer 'foo 75))
    (check-mock-called-with? should-retry-mock (arguments 'foo 5))
    (check-pred void? (retryer-handle cyclic-retryer 'foo 75))
    (check-mock-called-with? handle-mock (arguments 'foo 5))))
