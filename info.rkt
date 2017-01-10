#lang info
(define collection "retry")
(define scribblings '(("scribblings/main.scrbl" (multi-page) (library) "retry")))
(define compile-omit-paths '("private"))
(define deps '("compose-app"
               "fancy-app"
               "gregor-lib"
               "reprovide-lang"
               ("base" #:version "6.5")
               "mock"))
(define build-deps '("at-exp-lib"
                     "gregor-doc"
                     "scribble-text-lib"
                     "racket-doc"
                     "scribble-lib"
                     "rackunit-lib"
                     "mock-rackunit"))
