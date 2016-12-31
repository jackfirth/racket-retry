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
