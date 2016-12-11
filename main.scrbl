#lang scribble/manual

@(require "doc-base.rkt")

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