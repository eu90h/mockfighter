#lang racket
(require web-server/servlet
         web-server/servlet-env
         rackunit
         "utils.rkt"
         "server.rkt"
         stockfighter-api)
(define server-thread (run-mockfighter))
(sleep 2)
(define sf (new stockfighter% [key "1C2B3A4"]))
(send sf set-ob-endpoint "127.0.0.1")
(send sf set-gm-endpoint "127.0.0.1")
(send sf set-port 8000)
(send sf ssl-off)
(check-true (send sf is-api-up?))

(define game-data (send sf new-instance "test"))
(define venues (hash-ref game-data `venues))
(define stocks (hash-ref game-data `tickers))
(define venue (first venues))
(define stock (first stocks))
(define account (hash-ref game-data `account))

(check-false (send sf is-venue-up? "blah"))
(check-true (send sf is-venue-up? venue))

(define buy-data (send sf post-order account venue stock 1000 40 "buy" "limit"))
(define sell-data (send sf post-order account venue stock 1050 40 "sell" "limit"))
(check-true (ok? buy-data))
(check-true (ok? sell-data))
(define quote-data (send sf get-quote venue stock))
(check-true (ok? quote-data))
(define buy-id (order-id buy-data))
(check-true (ok? (send sf get-order-status venue stock buy-id)))
(check-true (ok? (send sf get-stocks venue)))
(check-true (ok? (send sf cancel-order venue stock buy-id)))
(check-true (ok? (send sf get-orderbook venue stock)))

(sleep 25) ; wait roughly 5 trading days
(kill-thread server-thread)