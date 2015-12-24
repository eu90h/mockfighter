#lang racket
(require stockfighter-api mockfighter net/url net/rfc6455)

(define-values (server-thread run-bots) (run-mockfighter))
(sleep 2)

(define sf (new stockfighter% [key "1C2B3A4"]))
(send sf set-ob-endpoint "127.0.0.1")
(send sf set-gm-endpoint "127.0.0.1")
(send sf set-port 8000)
(send sf ssl-off)

(define game-data (send sf new-instance "test"))
(define venue (hash-ref game-data 'venue))
(define stock (hash-ref game-data `symbol))
(define account (hash-ref game-data 'account))

(sleep 2)

(define ticker (open-feed (string->url (string-append
                "ws://127.0.0.1:8001/ob/api/ws/"
                account
                "/venues/"
                venue
                "/tickertape/stocks/"
                stock))))

(define (start)
  (let loop ()
    (when (feed-ready? ticker)
      (displayln (read-feed ticker)))
    (loop)))

(thread start)
(run-bots)