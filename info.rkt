#lang info
(define collection "retry")
(define scribblings '(("main.scrbl" () (library) "retry")))
(define compile-omit-paths '("private"))
(define deps '("base"))
(define build-deps '("racket-doc"
                     "scribble-lib"))
