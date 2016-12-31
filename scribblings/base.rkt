#lang racket/base

(provide (for-label (all-from-out gregor
                                  gregor/period
                                  racket/base
                                  racket/contract
                                  racket/function
                                  retry))
         define-retry-examples-syntax
         retry-examples
         retryer-tech
         source-code-link)

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
  (make-base-eval #:lang 'racket/base (list 'require 'retry 'racket/function)))

(define-simple-macro (retry-examples example:expr ...)
  (examples #:eval (make-retry-eval) example ...))

(define-simple-macro (define-retry-examples-syntax id:id)
  (begin
    (define evaluator (make-retry-eval))
    (define-simple-macro (id example:expr (... ...))
      (examples #:eval evaluator example (... ...)))))

(define (source-code-link url-str)
  (begin/text "Source code for this library is avaible at " (url url-str)))

(define ((tech-helper key) #:definition? [definition? #f] . pre-flow)
  (apply (if definition? deftech tech) #:key key pre-flow))

(define retryer-tech (tech-helper "retryer"))
