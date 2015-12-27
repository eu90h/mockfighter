#lang racket
(require stockfighter-api math)
(provide mm%)
(define noise-dist (normal-dist 0 60))
(define (gaussian-noise)
  (sample noise-dist))
(define mm%
  (class object% (super-new)
    (init-field api-key venue stock account venue-name)
    (field [sf (new stockfighter% [key api-key])]
           [cur-order null])
    (send sf set-ob-endpoint "127.0.0.1")
    (send sf set-gm-endpoint "127.0.0.1")
    (send sf set-port 8000)
    (send sf ssl-off)
    
    (define/public (trade)
      (define fmv (inexact->exact (truncate (+ (send venue get-fmv stock) (gaussian-noise)))))
      (unless (null? cur-order)
        (send sf cancel-order (order-venue cur-order) (order-symbol cur-order) (order-id cur-order)))
      (set! cur-order (send sf post-order account venue-name stock fmv (random-integer 20 100) (if (= 1 (random 2))
                                                                                                   "buy" "sell") "limit")))))