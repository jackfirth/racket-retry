#lang scribble/manual
@(require "base.rkt")

@title[#:tag "retry-guide"]{The Retry Guide}
@(define-retry-examples-syntax retry-intro-examples)

This guide is intended for programmers who are familiar with Racket but new to
working with @retryer-tech{retryers}. It contains a description of the high
level concepts associated with the @racketmodname[retry] library, as well as
examples and use cases. For a complete description of the @racketmodname[retry]
API, see @secref{retry-reference}.

@section{Intro to Retryers}

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
when a failing operation @emph{should} be retried, and one that defines
@emph{how} to handle the failure. Then, we can call a possibly-failing procedure
with retries by using @racket[call/retry].

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
  (eval:check (call/retry my-retryer (make-flaky-procedure)) 'success))

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

While @retryer-tech{retryers} can perform arbitrarily complex operations, most
applications only need to perform a few kinds of tasks when retrying. The
@racketmodname[retry] library provides procedures out of the box to create
retryers for these tasks. Included are retryers for printing messages, waiting
for certain amounts of time, and limiting the number of retries.

@subsection{Printing Retryers}

The @racket[print-exn-retryer] procedure takes a function for converting
exception messages and the number of retries into a string and constructs a
retryer. That retryer uses the given function to print a message with
@racket[displayln]:

@(retry-intro-examples
  (define (retry-failure-to-string msg num-previous-retries)
    (format "Failed attempt ~a, message: ~a" (add1 num-previous-retries) msg))
  (define printing-retryer (print-exn-retryer retry-failure-to-string))
  (eval:check (call/retry printing-retryer (make-flaky-procedure)) 'success))

Note that only exceptions have messages, but @racket[raise]d values might not
necessarily be exceptions. Thus, a retryer created with
@racket[print-exn-retryer] only handles exceptions - any other raised values
are raised normally instead of retried.

@subsection{Limiting Retryers}

The @racket[limit-retryer] procedure is relatively simple. Given a maximum
number of times to retry, the returned retryer only handles thrown values if
fewer that that many retries have occurred:

@(retry-intro-examples
  (eval:error (call/retry (limit-retryer 2) (make-flaky-procedure)))
  (eval:check (call/retry (limit-retryer 5) (make-flaky-procedure)) 'success))

@subsection{Sleeping Retryers}

Often temporary failures are due to factors completely outside our control,
where the only recourse is to wait some amount of time for the issue to fix
itself. For these cases, we can construct retryers that call @racket[sleep] to
pause between retries. This library uses Gregor @racket[period] structures to
determine how long to sleep for, in contrast to the fractional seconds used when
calling @racket[sleep] directly. The periods used must satisfy
@racket[time-period?].

The simplest of the sleeping retryers is @racket[sleep-const-retryer]. Retryers
returned by this procedure sleep for a constant amount of time (determined by a
period given to @racket[sleep-const-retryer]) between retries. In the following
examples we have altered the behavior of @racket[sleep] slightly; instead of
actually pausing execution, the amount of seconds to sleep for will be printed
out and no sleeping will occur. If you evaluate these expressions in a normal
Racket REPL, expect long execution times with no output.

@(retry-intro-examples
  (eval:check (call/retry (sleep-const-retryer (minutes 3))
                          (make-flaky-procedure))
              'success))

A more general form of retrying with pauses is available via
@racket[sleep-retryer]. Unlike @racket[sleep-const-retryer],
@racket[sleep-retryer] accepts a @emph{procedure} that is expected to map the
number of previous retries to a @racket[time-period?] value. This allows
sleeping retryers to vary how long they pause between retries. Lets use it to
build a retryer that sleeps for a linearly increasing number of minutes:

@(retry-intro-examples
  (define (sleep-amount num-previous-retries)
    (minutes (* 5 (add1 num-previous-retries))))
  (eval:check (call/retry (sleep-retryer sleep-amount)
                          (make-flaky-procedure))
              'success))

A very common pattern when attempting to open network connections is to sleep
between failures with @exp-backoff-tech[#:definition? #t]{exponential backoff}.
This means waiting for an exponentially increasing amount of time between
failures. Because of its ubiquity, the @racketmodname[retry] library provides
@racket[sleep-exponential-retryer] for retrying with exponential backoff:

@(retry-intro-examples
  (define exponential-retryer (sleep-exponential-retryer (seconds 10)))
  (eval:check (call/retry exponential-retryer (make-flaky-procedure))
              'success))

Additionally, three more procedures are provided: @racket[sleep-retryer/random],
@racket[sleep-const-retryer/random], and
@racket[sleep-exponential-retryer/random]. These procedures produce retryers
that sleep for @emph{random} amounts of time, up to a maximum of what their
counterpart retryers would sleep for. This is useful for adding
@jitter-tech[#:definition? #t]{jitter}: variation in a group of retrying agents
that causes them to fall out of synchronization (see the
@thundering-herd-problem). Now, lets consider what happens if we take
@racket[sleep-const-retryer] and add some randomness.

@(retry-intro-examples
  (eval:check (call/retry (sleep-const-retryer/random (seconds 30))
                          (make-flaky-procedure))
              'success))

The unit of the returned @racket[time-period?] affects the randomness. Returning
a @racket[minutes] period causes a random number of minutes to be chosen as the
sleep amount, while returning the equivalent @racket[milliseconds] period
chooses a random amount of milliseconds. Observe the difference between using
@racket[(minutes 5)] and @racket[(seconds 300)]:

@(retry-intro-examples
  (eval:check (call/retry (sleep-const-retryer/random (minutes 5))
                          (make-flaky-procedure))
              'success))
@(retry-intro-examples
  (eval:check (call/retry (sleep-const-retryer/random (seconds 300))
                          (make-flaky-procedure))
              'success))

@section[#:tag "retry-complex"]{Building Complex Retryers}
@section{Retrying Principles and Applications}
