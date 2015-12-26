#lang racket
(require stockfighter-api mockfighter net/url net/rfc6455 math)

(define server-thread (run-mockfighter))
(sleep 2)

(define sf (new stockfighter% [key "1C2B3A4"]))
(send sf set-ob-endpoint "127.0.0.1")
(send sf set-gm-endpoint "127.0.0.1")
(send sf set-port 8000)
(send sf ssl-off)

(define game-data (send sf new-instance "test"))
(define venue (first (hash-ref game-data 'venues)))
(define stock (first (hash-ref game-data `tickers)))
(define account (hash-ref game-data 'account))

(sleep 2)

(define ticker (open-feed (string->url (string-append
                "ws://127.0.0.1:8001/ob/api/ws/"
                account
                "/venues/"
                venue
                "/tickertape/stocks/"
                stock))))
(define executions (open-feed (string->url (string-append
                "ws://127.0.0.1:8001/ob/api/ws/"
                account
                "/venues/"
                venue
                "/executions/stocks/"
                stock))))

(define (start)
  (let loop ()
    (send sf post-order account venue stock 1 (random-integer 1 300) "sell" "limit")
    (when (feed-ready? executions)
     (displayln (read-feed executions)))
    (when (feed-ready? ticker)
     (displayln (read-feed ticker)))
    (loop)))

(define t (thread start))
(sleep 100)
(kill-thread t)