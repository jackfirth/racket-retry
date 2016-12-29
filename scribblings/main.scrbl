#lang scribble/manual

@(require "base.rkt")

@title{Retry: Retrying Arbitrary Computations}
@defmodule[retry #:packages ("retry")]
@author[@author+email["Jack Firth" "jackhfirth@gmail.com"]]

This library provides utilities for defining
@retryer-tech{retryers}, values that describe how to retry an operation.
Retryers can be used to attempt some operation and retry it in the event of
failure. Retryers can be composed, allowing complex retry logic to be broken
down into individual components. Retryers are exceptionally useful anytime an
operation has inherent dependencies on time and external systems - for example,
attempting to acquire a database connection when a database might be temporarily
down or not yet initialized.

@source-code-link{https://github.com/jackfirth/racket-retry}

@table-of-contents[]
@include-section["guide.scrbl"]
@include-section["reference.scrbl"]
