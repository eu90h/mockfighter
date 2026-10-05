#lang info
(define collection "mockfighter")
(define deps '("data-lib"
               "math-lib"
               "rfc6455"
               "web-server-lib"
               "base"
               "rackunit-lib"
               "stockfighter-racket"))
(define build-deps '("scribble-lib" "racket-doc"))
(define scribblings '(("scribblings/mockfighter.scrbl" ())))
(define pkg-desc "Mockfighter - Stockfighter Clone")
(define version "0.0")
(define pkg-authors '(eu90h))
