#lang racket/base

(provide retry-examples
         retry-policy-tech
         retryer-tech
         source-code-link)

(require scribble/example
         scribble/manual
         scribble/text)

(define (make-retry-eval)
  (make-base-eval #:lang 'racket/base (list 'require 'retry)))

(define-syntax-rule (retry-examples example ...)
  (examples #:eval (make-retry-eval) example ...))

(define (source-code-link url-str)
  (begin/text "Source code for this library is avaible at " (url url-str)))

(define ((tech-helper key) #:definition? [definition? #f] . pre-flow)
  (apply (if definition? deftech tech) #:key key pre-flow))

(define retry-policy-tech (tech-helper "retry-policy"))
(define retryer-tech (tech-helper "retryer"))
