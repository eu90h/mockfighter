#lang racket
(require stockfighter-api math)
(provide noise-trader%)
(define noise-trader%
  (class object% (super-new)
    (init-field api-key account venue-name stock venue)
    (field [sf (new stockfighter% [key api-key])])
    (send sf set-ob-endpoint "127.0.0.1")
    (send sf set-gm-endpoint "127.0.0.1")
    (send sf set-port 8000)
    (send sf ssl-off)
   
    (define/public (set-api-key key)
      (set! api-key key)
      (set! sf (new stockfighter% [key api-key]))
      (send sf set-ob-endpoint "127.0.0.1")
      (send sf set-gm-endpoint "127.0.0.1")
      (send sf set-port 8000)
      (send sf ssl-off))
    
    (define/public (trade)
      (define fmv (send venue get-fmv stock))
      (send sf post-order account venue-name stock fmv (random-integer 5 200) (if (= 1 (random 2))
                                                                                  "buy" "sell") "market"))))