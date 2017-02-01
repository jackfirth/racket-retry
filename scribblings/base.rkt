#lang at-exp racket/base

(provide (for-label (all-from-out gregor
                                  gregor/period
                                  racket/base
                                  racket/contract
                                  racket/function
                                  retry))
         exp-backoff-tech
         define-retry-examples-syntax
         jitter-tech
         retryer-tech
         source-code-link
         thundering-herd-problem)

(require (for-label gregor
                    gregor/period
                    (except-in racket/base date date?)
                    racket/contract
                    racket/function
                    retry)
         scribble/example
         scribble/manual
         scribble/text
         syntax/parse/define)

(define (make-retry-eval)
  (make-base-eval #:lang 'racket/base
                  '(require gregor
                            gregor/period
                            racket/function
                            retry
                            retry/private/inject)
                  '(define (secret-new-sleep secs)
                     (printf "Sleeping for ~a seconds...\n" secs))
                  '(current-sleep secret-new-sleep)))

(define-simple-macro (define-retry-examples-syntax id:id)
  (begin
    (define evaluator (make-retry-eval))
    (define-simple-macro (id example:expr (... ...))
      (examples #:eval evaluator example (... ...)))))

(define (source-code-link url-str)
  (begin/text "Source code for this library is avaible at " (url url-str)))

(define ((tech-helper key) #:definition? [definition? #f] . pre-flow)
  (apply (if definition? deftech tech) #:key key pre-flow))

(define exp-backoff-tech (tech-helper "exponential backoff"))
(define jitter-tech (tech-helper "jitter"))
(define retryer-tech (tech-helper "retryer"))

(define thundering-herd-problem
  @hyperlink["https://en.wikipedia.org/wiki/Thundering_herd_problem"]{
 thundering herd problem})
