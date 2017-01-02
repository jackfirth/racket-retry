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
that fails with an exception the first few times its called. This will help us
explore strategies for retrying calls to flaky code.

@(retry-intro-examples
  (struct exn:fail:flaky exn:fail () #:transparent)
  (define (make-flaky-procedure #:num-failures num-failures)
    (define num-calls (box 0))
    (thunk
     (when (< (unbox num-calls) num-failures)
       (set-box! num-calls (add1 (unbox num-calls)))
       (raise (exn:fail:flaky "not good enough!" (current-continuation-marks))))
     'success)))

The flaky procedures returned by @racket[make-flaky-procedure] store the number
of times they've been called in a @racket[box], and increment that number before
throwing an @racket[exn:fail:flaky] when they're called:

@(retry-intro-examples
  (define example-flaky-proc (make-flaky-procedure #:num-failures 3))
  (eval:error (example-flaky-proc)))

Once our flaky procedure is called for the fourth time, it starts returning
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
  (eval:check (call/retry my-retryer (make-flaky-procedure #:num-failures 3))
              'success))

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

@subsection[#:tag "retry-print"]{Printing Retryers}

The @racket[print-exn-retryer] procedure takes a function for converting
exception messages and the number of retries into a string and constructs a
retryer. That retryer uses the given function to print a message with
@racket[displayln]:

@(retry-intro-examples
  (define (retry-failure-to-string msg num-previous-retries)
    (format "Failed attempt ~a, message: ~a" (add1 num-previous-retries) msg))
  (define printing-retryer (print-exn-retryer retry-failure-to-string))
  (eval:check (call/retry printing-retryer
                          (make-flaky-procedure #:num-failures 3))
              'success))

Note that only exceptions have messages, but @racket[raise]d values might not
necessarily be exceptions. Thus, a retryer created with
@racket[print-exn-retryer] only handles exceptions - any other raised values
are raised normally instead of retried.

@subsection{Limiting Retryers}

The @racket[limit-retryer] procedure is relatively simple. Given a maximum
number of times to retry, the returned retryer only handles thrown values if
fewer that that many retries have occurred:

@(retry-intro-examples
  (define at-most-four-retryer (limit-retryer 4))
  (eval:error
   (call/retry at-most-four-retryer (make-flaky-procedure #:num-failures 5)))
  (eval:check
   (call/retry at-most-four-retryer (make-flaky-procedure #:num-failures 3))
   'success))

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
                          (make-flaky-procedure #:num-failures 3))
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
                          (make-flaky-procedure #:num-failures 3))
              'success))

A very common pattern when attempting to open network connections is to sleep
between failures with @exp-backoff-tech[#:definition? #t]{exponential backoff}.
This means waiting for an exponentially increasing amount of time between
failures. Because of its ubiquity, the @racketmodname[retry] library provides
@racket[sleep-exponential-retryer] for retrying with exponential backoff:

@(retry-intro-examples
  (define exponential-retryer (sleep-exponential-retryer (seconds 10)))
  (eval:check
   (call/retry exponential-retryer (make-flaky-procedure #:num-failures 3))
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
                          (make-flaky-procedure #:num-failures 3))
              'success))

The unit of the returned @racket[time-period?] affects the randomness. Returning
a @racket[minutes] period causes a random number of minutes to be chosen as the
sleep amount, while returning the equivalent @racket[milliseconds] period
chooses a random amount of milliseconds. Observe the difference between using
@racket[(minutes 5)] and @racket[(seconds 300)]:

@(retry-intro-examples
  (eval:check (call/retry (sleep-const-retryer/random (minutes 5))
                          (make-flaky-procedure #:num-failures 3))
              'success))
@(retry-intro-examples
  (eval:check (call/retry (sleep-const-retryer/random (seconds 300))
                          (make-flaky-procedure #:num-failures 3))
              'success))

@section[#:tag "retry-complex"]{Building Complex Retryers}

Each of the built-in retryers we've seen so far in @secref{retry-predefined} has
a single purpose. However, in the real world we often wish to combine many of
these behaviors. We may wish for a retryer that retries at most three times,
sleeps an increasing amount of time between retries, and prints information
about failures to the console. Instead of reaching for our own custom
implementations as soon as the going gets tough, we can combine our existing
simple retryers together to declaritively construct complex retryers.

@subsection{Retryer Composition}

The simplest means of combining retryers is @racket[retryer-compose]. This
procedure takes a list of retryers and returns one composed retryer, which calls
each given retryer to determine if and how to handle failures. Recall our
@racket[printing-retryer] from @secref{retry-print}; we can add sleeping with
@racket[retryer-compose]:

@(retry-intro-examples
  (define composed-retryer
    (retryer-compose (sleep-const-retryer (seconds 10)) printing-retryer))
  (call/retry composed-retryer (make-flaky-procedure #:num-failures 3)))

Note that although @racket[printing-retryer] is the second argument to
@racket[retryer-compose], it is called @emph{first} when a failure is handled.
This mimics the behavior of function composition with @racket[compose]; retryers
are called in right-to-left order.

@subsection{Cyclic Retryers}

In previous sections, we discussed @racket[sleep-exponential-retryer] and the
utility of creating retryers that sleep increasing amounts of time between
retries. This can be troublesome if the retries are unbounded; eventually the
pauses between retries could reach days or weeks. Using @racket[cycle-retryer],
we can extend retryers with @emph{cyclic} behavior so that the number of retries
appears to "reset". 

@(retry-intro-examples
  (call/retry (cycle-retryer (sleep-exponential-retryer (seconds 10)) 4)
              (make-flaky-procedure #:num-failures 10)))

@subsection{In Depth Example: Cyclic Exponential Backoff with Jittering}

Putting together all the concepts we've learned so far, let's consider how a web
server might reliable handle the failure of a database it retrieves information
from. It would be most unfortunate if a small temporary network issue caused our
website to permanently fail. There's a host of other contraints as well:

@itemlist[
 @item{A small hiccup may be resolved in seconds, we shouldn't be waiting for
  minutes or hours after our first retry.}
 @item{Bandwidth is expensive. If the database is down for hours, retrying every
  few seconds can be costly and lead to network congestion.}
 @item{Reconnection should occur quickly when the database comes back online.}
 @item{There may be hundreds or thousands of instances of our website trying to
  connect, if they all make requests in synchronization the spiky network load
  can cause failures and overloads.}
 @item{We should only retry when faced with @emph{network} errors. Permission
  and configuration errors are far less likely to resolve themselves, and by
  retrying forever we mask their existence.}]

To address these constraints, we'll combine three main elements in our retry
strategy:

@itemlist[
 @item{Adding a quick test of the raised exception to verify we're dealing with
  a network issue instead of some other more-permanent problem.}
 @item{@exp-backoff-tech{Exponential backoff} with
  @racket[sleep-exponential-retryer]. This lets us reconnect quickly in the
  event of small hiccups, but we won't make unnecessary requests when faced with
  a large outage.}
 @item{Cycling the backoff with @racket[cycle-retryer]. Using plain exponential
  backoff can result in large waits to reconnect when the database comes back
  online. If the time between retries doubles, then a one-hour outage in the
  database could trigger a two-hour outage in our website: reconnection is
  attempted just before the database comes back online and fails with the next
  retry not occurring for another hour. Cycling sets an upper bound on how long
  we wait between retries.}
 @item{Adding @jitter-tech{jitter} with @racket[sleep-const-retryer/random].
  When a database outage first occurs, our websites will attempt to reconnect
  (mostly) in sync with each other. By adding jitter they will gradually fall
  out of resynchronization, spreading the network load around as we reach the
  larger periods between retries with our exponential backoff.}]

By combining these elements (along with @racket[print-exn-retryer]), we end up
with a retryer looking something like this. Note that we're assuming an
@racket[exn:fail:flaky] is raised instead of @racket[exn:fail:network], this
helps us demonstrate our retryer.

@(retry-intro-examples
  (define (database-retry-message exn-msg num-previous-retries)
    (format "Failed database connection attempt ~a, message: ~a"
            (add1 num-previous-retries)
            exn-msg))
  (define database-retryer
    (retryer-compose (cycle-retryer (sleep-exponential-retryer (seconds 1)) 8)
                     (sleep-const-retryer/random (seconds 5))
                     (print-exn-retryer database-retry-message)
                     (retryer #:should-retry? (λ (r n) (exn:fail:flaky? r))))))

Lets test out this retryer with different outage scenarios, simulated with
@racket[make-flaky-procedure].

@(retry-intro-examples
  (call/retry database-retryer (make-flaky-procedure #:num-failures 3))
  (call/retry database-retryer (make-flaky-procedure #:num-failures 10)))
