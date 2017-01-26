#lang racket/base

(require racket/contract/base)

(provide
 (contract-out
  [time-period->unit
   (-> time-period? time-unit/c (and/c rational? (not/c negative?)))]
  [*period (-> period? exact-nonnegative-integer? period?)]
  [unit-period (-> time-unit/c exact-nonnegative-integer? period?)]
  [random-period (-> period? period?)]))

(require fancy-app
         gregor
         gregor/period
         "inject.rkt")

(module+ test
  (require rackunit))


(define epoch (datetime 1970))

(define (unit-period unit amount)
  ((case unit
     [(years) years]
     [(months) months]
     [(weeks) weeks]
     [(days) days]
     [(hours) hours]
     [(minutes) minutes]
     [(seconds) seconds]
     [(milliseconds) milliseconds]
     [(microseconds) microseconds]
     [(nanoseconds) nanoseconds]) amount))

(define (time-period->unit tp unit)
  (define (calculate ratio)
    (* (nanoseconds-between epoch (+period epoch tp))
       (/ ratio 1000000000)))
  (calculate
   (case unit
     [(hours) 1/3600]
     [(minutes) 1/60]
     [(seconds) 1]
     [(milliseconds) 1000]
     [(microseconds) 1000000]
     [(nanoseconds) 1000000000])))

(module+ test
  (check-equal? (time-period->unit (seconds 5) 'hours) 5/3600)
  (check-equal? (time-period->unit (seconds 5) 'minutes) 5/60)
  (check-equal? (time-period->unit (seconds 5) 'seconds) 5)
  (check-equal? (time-period->unit (seconds 5) 'milliseconds) 5000)
  (check-equal? (time-period->unit (seconds 5) 'microseconds) 5000000)
  (check-equal? (time-period->unit (seconds 5) 'nanoseconds) 5000000000))

(define (unit-amount->period unit-amount-pair)
  (unit-period (car unit-amount-pair) (cdr unit-amount-pair)))

(define (list->period unit-amount-list)
  (apply period (map unit-amount->period unit-amount-list)))

(define (map-period proc p)
  ;; could be done nicer with lenses, but that's a heavyweight dependency
  (define (apply-proc-to-pair unit-amount-pair)
    (cons (car unit-amount-pair) (proc (cdr unit-amount-pair))))
  (list->period (map apply-proc-to-pair (period->list p))))

(define (*period p multiplicand)
  (map-period (* _ multiplicand) p))

(define (random-period max-period)
  (define (random/zero maybe-zero)
    (if (zero? maybe-zero) 0 (random* maybe-zero)))
  (map-period random/zero max-period))
