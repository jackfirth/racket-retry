#lang info
(define collection "retry")
(define scribblings '(("scribblings/main.scrbl" (multi-page) (library) "retry")))
(define compile-omit-paths '("private"))
(define deps '("gregor-lib"
               "reprovide-lang"
               "base"))
(define build-deps '("scribble-text-lib"
                     "racket-doc"
                     "scribble-lib"))
