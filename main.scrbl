#lang scribble/manual

@(require "private/doc-base.rkt")

@title{Retry: Generic Retrying Operations}
@author[@author+email["Jack Firth" "jackhfirth@gmail.com"]]

This library provides utilities for defining
@retryer-tech[#:definition? #t]{retryers}, values that describe how to retry
an operation. Retryers can be used to attempt some operation and retry it in the
event of failure, with hooks in place for evaluating expressions before and
after retries. Retryers can be constructed from
@retry-policy-tech[#:definition? #t]{retry policies}, plain structured data
describing how long to wait between retries, whether to retry continuously, what
backoff strategy to use, etc. Retryers are exceptionally useful anytime an
operation has inherent dependencies on time and external systems - for example,
attempting to acquire a database connection when a database might be temporarily
down or not fully started up yet.

@source-code-link{https://github.com/jackfirth/racket-retry}

@section{API Reference}
@defmodule[retry]

@defproc[(retryer? [v any/c]) boolean?]{
 A predicate that returns true when @racket[v] is a @retryer-tech{retryer}, and
 false otherwise.}

@defthing[immediate-logging-retryer retryer?]{
 A @retryer-tech{retryer} that always retries without any delay when any
 @racket[exn?] is thrown. The thrown exception's message is logged to
 @racket[current-output-port]. See @racket[call/retry] for an example usage.}

@defproc[(call/retry [retryer retryer?] [proc (-> any)]) any]{
 Calls @racket[proc] and catches any thrown exceptions, then consults the given
 @retryer-tech{retryer} to determine whether @racket[proc] should be called
 again.

 If a value @racket[v] is thrown on the @racket[n]th retry,
 @racket[(retryer-handle retryer v n)] is called to handle the exception (or
 rethrow it if the retryer doesn't handle this particular kind of exception).
 The value of @racket[n] starts at zero. Then,
 @racket[(retryer-should-retry? retryer n)] is called to determine whether to
 retry. If that returns true, @racket[proc] is called again and this process
 repeats. Otherwise, the value @racket[v] is rethrown and attempts to call
 @racket[proc] are abandoned. Invocations of @racket[call/retry] may never
 terminate, as some retryers never stop retrying.
 @(retry-examples
   (define num-times (box 0))
   (define (fail-first-three-times)
     (when (< (unbox num-times) 3)
       (set-box! num-times (add1 (unbox num-times)))
       (raise (make-exn "not today!" (current-continuation-marks))))
     'success)
   (call/retry immediate-logging-retryer fail-first-three-times))
 For a shorthand syntax, see @racket[with-retry].}

@defform[(with-retry retryer-expr body ...)
         #:contracts ([retryer-expr retryer?])]{
 Equivalent to @racket[(call/retry retryer-expr (λ () body ...))].}

@defproc[(retryer-handle [retryer retryer?]
                         [thrown any/c]
                         [num-previous-retries exact-nonnegative-integer?])
         void?]{
 Dispatches to @racket[retryer] to determine how to handle @racket[thrown] after
 @racket[num-previous-retries] retries.
 @(retry-examples
   (retryer-handle immediate-logging-retryer
                   (make-exn "something went wrong"
                             (current-continuation-marks))
                   3))}

@defproc[(retryer-should-retry?
          [retryer retryer?]
          [num-previous-retries exact-nonnegative-integer?])
         boolean?]{
 Dispatches to @racket[retryer] to determine whether an operation should retry
 after @racket[num-previous-retries] retries.
 @(retry-examples
   (retryer-should-retry? immediate-logging-retryer 5))}
