#lang scribble/manual
@(require "base.rkt")

@title[#:tag "retry-reference"]{The Retry Reference}

This document describes the complete API of the @racketmodname[retry] library.
For a gentler introduction and use cases, see @secref{retry-guide}.

@section{Core Retry API}

@defproc[(retryer? [v any/c]) boolean?]{
 A predicate that returns true when @racket[v] is a @retryer-tech{retryer}, and
 false otherwise.}

@defproc[(retryer [#:handle handle-proc
                   (-> any/c exact-nonnegative-integer? void?)
                   void]
                  [#:should-retry? should-retry-proc
                   (-> any/c exact-nonnegative-integer? boolean?)
                   (const #t)])
         retryer?]{
 Returns a @retryer-tech{retryer} that retries when @racket[should-retry-proc]
 returns true and handles failures with @racket[handle-proc]. See
 @racket[call/retry] for details on how these procedures are called to retry
 failures. Using only the default procedures for both cases produces a retryer
 equivalent to @racket[always-retryer].}

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
 terminate, as some retryers never stop retrying. For a shorthand syntax, see
 @racket[with-retry].}

@defform[(with-retry retryer-expr body ...)
         #:contracts ([retryer-expr retryer?])]{
 Equivalent to @racket[(call/retry retryer-expr (λ () body ...))].}

@defproc[(retryer-handle [retryer retryer?]
                         [raised any/c]
                         [num-previous-retries exact-nonnegative-integer?])
         void?]{
 Dispatches to @racket[retryer] to determine how to handle @racket[raised] after
 @racket[num-previous-retries] retries.}

@defproc[(retryer-should-retry?
          [retryer retryer?]
          [raised any/c]
          [num-previous-retries exact-nonnegative-integer?])
         boolean?]{
 Dispatches to @racket[retryer] to determine whether an operation should retry
 when @racket[raised] was raised after @racket[num-previous-retries] retries.}

@section{Built-In Retryers}

@defthing[always-retryer retryer? #:value (retryer)]{
 The always retryer. Swallows all failures and retries without restriction.}

@defthing[never-retryer retryer? #:value (retryer #:should-retry? (const #f))]{
 The never retryer. Does absolutely nothing in the face of failure and never
 retries.}

@defproc[(limit-retryer [limit exact-nonnegative-integer?]) retryer?]{
 Returns a retryer that only retries a maximum of @racket[limit] times.}

@defproc[(print-exn-retryer
          [to-string (-> string? exact-nonnegative-integer? string?)])
         retryer?]{
 Returns a retryer that handles raised @racket[exn?] values by calling
 @racket[to-string] with the raised exception's message and the number of
 previous retries, and then passing the resulting string to @racket[displayln].}

@defproc[(sleep-retryer
          [sleep-amount
           (-> exact-nonnegative-integer? exact-nonnegative-integer?)])
         retryer?]{
 Returns a retryer that handles all raised values by @racket[sleep]-ing for an
 amount of milliseconds determined by calling @racket[sleep-amount] with the
 number of previous retries.}

@section{Higher-Order Retryers}

@defproc[(retryer-compose [ret retryer?] ...) retryer?]{
 Returns a retryer that is a composition of the given retryers. The returned
 retryer retries a failure only if every @racket[ret] retries that failure in
 the sense of @racket[retryer-should-retry?]. To handle failures, the composed
 retryer calls each @racket[ret] using @racket[retryer-handle]. The first
 @racket[ret] is called last in both these operations, giving right-to-left
 composition in the same manner as function composition with @racket[compose].}

@defproc[(cycle-retryer [ret retryer?] [cycle-length exact-positive-integer?])
         retryer?]{
 Returns a retryer that is like @racket[ret], but takes the number of previous
 retries from @racket[retryer-should-retry?] and @racket[retryer-handle] and
 resets it on a cycle of length @racket[cycle-length] using @racket[modulo].
 This allows creation of retryers that perform some cyclic behavior, such as
 implementing a retryer on top of @racket[sleep-exponential-retryer] that resets
 the exponential backoff cycle after @racket[cycle-length] retries.}
