#lang racket
(require stockfighter-api math)
(provide mm%)
(define mm%
  (class object% (super-new)
    (init-field api-key account venue-name stock venue)
    (field [sf (new stockfighter% [key api-key])])
    (send sf set-endpoint "127.0.0.1")
      (send sf set-port 8000)
      (send sf set-ssl #f)

    (define/public (set-api-key key)
      (set! api-key key)
      (set! sf (new stockfighter% [key api-key]))
      (send sf set-endpoint "127.0.0.1")
      (send sf set-port 8000)
      (send sf set-ssl #f))
    
    (define/public (trade)
      (define fmv (send venue get-fmv stock))
      (displayln (send sf post-order account venue-name stock fmv (random-integer 20 100) (if (= 1 (random 2))
                                                                                   "buy" "sell") "limit")))
    ))