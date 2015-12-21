#lang racket
(require srfi/19)
(provide (contract-out
          [date-string->time-utc (-> string? time?)]
          [date-string<=? (-> string? string? boolean?)]
          [date-string>=? (-> string? string? boolean?)]
          [date-string<? (-> string? string? boolean?)]
          [date-string>? (-> string? string? boolean?)]
          [date-string=? (-> string? string? boolean?)]
          [current-time->string (-> string?)]))
(define date-format-string "~Y-~m-~dT~H:~M:~S.~NZ")

(define (current-time->string)
  (date->string (time-utc->date (current-time)) date-format-string))

(define (date-string->time-utc ds)
  (date->time-utc (string->date ds date-format-string)))

(define (date-string<=? ds0 ds1)
  (time<=? (date-string->time-utc ds0) (date-string->time-utc ds1)))

(define (date-string>=? ds0 ds1)
  (time>=? (date-string->time-utc ds0) (date-string->time-utc ds1)))

(define (date-string<? ds0 ds1)
  (time<? (date-string->time-utc ds0) (date-string->time-utc ds1)))

(define (date-string>? ds0 ds1)
  (time>? (date-string->time-utc ds0) (date-string->time-utc ds1)))

(define (date-string=? ds0 ds1)
  (time=? (date-string->time-utc ds0) (date-string->time-utc ds1)))

(module+ test
  (require rackunit stockfighter-api)
  (check-equal? (date-string->time-utc "2015-11-29T02:53:45.95810547Z")
                (make-time `time-utc 958105470 1448783625))
  
  (check-true (date-string<=? "2015-11-29T02:53:45.95810547Z"
                              "2015-11-29T02:53:45.95810548Z"))
  (check-false (date-string<=? "2015-11-29T02:53:45.95810548Z"
                               "2015-11-29T02:53:45.95810547Z"))
  (check-true (date-string<=? "2015-11-29T02:53:45.95810547Z"
                              "2015-11-29T02:53:45.95810547Z"))
  
  (check-false (date-string>=? "2015-11-29T02:53:45.95810547Z"
                              "2015-11-29T02:53:45.95810548Z"))
  (check-true (date-string>=? "2015-11-29T02:53:45.95810548Z"
                               "2015-11-29T02:53:45.95810547Z"))
  (check-true (date-string>=? "2015-11-29T02:53:45.95810547Z"
                              "2015-11-29T02:53:45.95810547Z"))
  
  (check-false (date-string>? "2015-11-29T02:53:45.95810547Z"
                              "2015-11-29T02:53:45.95810548Z"))
  (check-true (date-string>? "2015-11-29T02:53:45.95810548Z"
                               "2015-11-29T02:53:45.95810547Z"))
  (check-false (date-string>? "2015-11-29T02:53:45.95810547Z"
                              "2015-11-29T02:53:45.95810547Z"))

  (check-true (date-string<? "2015-11-29T02:53:45.95810547Z"
                              "2015-11-29T02:53:45.95810548Z"))
  (check-false (date-string<? "2015-11-29T02:53:45.95810548Z"
                               "2015-11-29T02:53:45.95810547Z"))
  (check-false (date-string<? "2015-11-29T02:53:45.95810547Z"
                              "2015-11-29T02:53:45.95810547Z"))

  (check-true (date-string=? "2015-11-29T02:53:45.95810547Z"
                              "2015-11-29T02:53:45.95810547Z"))
  (check-false (date-string=? "2015-11-29T02:53:45.95810547Z"
                              "2015-11-29T02:53:45.95810548Z")))
                