#lang scribble/manual
@(require "base.rkt")

@title[#:tag "retry-guide"]{The Retry Guide}

This guide is intended for programmers who are familiar with Racket but new to
working with @retryer-tech{retryers}. It contains a description of the high
level concepts associated with the @racketmodname[retry] library, as well as
examples and use cases. For a complete description of the @racketmodname[retry]
API, see @secref{retry-reference}.

@section{Intro to Retryers}
@(define-retry-examples-syntax retry-intro-examples)

Sometimes, code fails. And sometimes, those failures are unpredictable - they
might happen again, they might not. A classic example is attempting to open an
internet connection - there's no way for code to know whether it will succeed or
fail due to network issues and machine failures. In a world of such uncertainty,
we must learn to handle temporary failure gracefully.

One way to handle temporary failures is by retrying. There are many different
ways to retry operations, but most include some combination of waiting for some
amount of time, logging information about the failure, and limiting the maximum
number of retry attempts. We can define a strategy for retrying by creating a
@retryer-tech[#:definition? #t]{retryer}. Retryers are made with the
@racket[retryer] procedure by combining two other procedures - one that defines
when a failing operation @emph{should} be retried, and one that defines how to
handle the failure. Then, we can call a possibly-failing procedure with retries
by using @racket[call/retry].

First, lets define a helper called @racket[make-flaky-procedure] that returns a
thunk (a procedure accepting no arguments, like those created by @racket[thunk])
that fails with an exception the first three times its called. This will help us
explore strategies for retrying calls to flaky code.

@(retry-intro-examples
  (struct exn:fail:flaky exn:fail () #:transparent)
  (define (make-flaky-procedure)
    (define num-calls (box 0))
    (thunk
     (when (< (unbox num-calls) 3)
       (set-box! num-calls (add1 (unbox num-calls)))
       (raise (exn:fail:flaky "not good enough!" (current-continuation-marks))))
     'success)))

The flaky procedures returned by @racket[make-flaky-procedure] store the number
of times they've been called in a @racket[box], and increment that number before
throwing an @racket[exn:fail:flaky] when they're called:

@(retry-intro-examples
  (define example-flaky-proc (make-flaky-procedure))
  (eval:error (example-flaky-proc)))

Once a flaky procedure is called for the fourth time, it starts returning
@racket['success]:

@(retry-intro-examples
  (eval:error (example-flaky-proc))
  (eval:error (example-flaky-proc))
  (eval:check (example-flaky-proc) 'success))

Now that we have a way to construct flaky code, lets create a
@retryer-tech{retryer} and use @racket[call/retry] to automatically call flaky
procedures multiple times:

@(retry-intro-examples
  (define my-retryer
    (retryer #:should-retry? (λ (raised num-previous-retries)
                               #t)
             #:handle (λ (raised num-previous-retries)
                        (printf "Failed attempt ~a, message: ~a\n"
                                (add1 num-previous-retries)
                                (exn-message raised)))))
  (call/retry my-retryer (make-flaky-procedure)))

A retryer is constructed from two procedures. Both are called during the extent
of @racket[call/retry] when the procedure given to @racket[call/retry] fails,
and both are given the thrown exception and the number of previous retries. The
first, the @racket[#:should-retry?] argument, is called to determine if this
retryer wants to retry the failure. Our retryer ignores both arguments and
always returns true, indicating that @racket[call/retry] should keep retrying no
matter what happens.

@margin-note{In a real world application, retrying forever can be dangerous and
 should be considered carefully. At the very least, unlimited retries should be
 restricted to a very targeted subtype of @racket[exn] rather than all possible
 values that could be @racket[raise]d.}

The second, the @racket[#:handle] argument, is called before retrying to perform
some arbitrary side-effect to handle the thrown exception. Our retryer prints
the message along with how many attempts we've made.

Instead of making our own retryers however, this library encourages constructing
retryers through @emph{composition}. Described in the next section
@secref{retry-predefined} are the built in retryers provided by
@racketmodname[retry] that implement simple targeted functionality. In the
following section @secref{retry-complex}, we show how to compose simple retryers
into more complex ones that perform multiple operations.

@section[#:tag "retry-predefined"]{Predefined Retryers}
@section[#:tag "retry-complex"]{Building Complex Retryers}
@section{Retrying Principles and Applications}
