#lang racket
(require web-server/servlet
         web-server/servlet-env
         json
         "utils.rkt" "game-master.rkt")

(provide run-mockfighter)

(define gm (new game-master%))

(define (display-documentation)
  (respond/error "not implemented"))

(define (handle-orderbook-request req api-key [method 'GET] #:post-data [data null])
  (cond [(equal? 'GET method)
         (cond [(equal? null req) (respond/error "unknown request")]
               [(equal? "heartbeat" (car req)) (respond (make-hash (list (cons `ok #t))))]
               [(and (= 3 (length req)) (equal? "venues" (car req)) (equal? "heartbeat" (caddr req))) (respond (send gm venue-heartbeat api-key (cadr req)))]
               [(and (= 3 (length req)) (equal? "venues" (car req)) (equal? "stocks" (caddr req))) (respond (send gm get-stocks api-key (cadr req)))]
               [(and (= 4 (length req)) (equal? "venues" (car req)) (equal? "stocks" (caddr req))) (respond (send gm get-orderbook api-key (cadr req) (cadddr req)))]
               [(and (= 5 (length req)) (equal? "venues" (car req)) (equal? "stocks" (caddr req)) (equal? "quote" (fifth req))) (respond (send gm get-quote api-key (cadr req) (cadddr req)))]
               [(and (= 6 (length req)) (equal? "venues" (car req)) (equal? "stocks" (caddr req)) (equal? "orders" (fifth req))) (respond (send gm get-order-status api-key (cadr req) (cadddr req) (string->number (sixth req))))]
               [else (respond/error "unknown request")])]
        [(equal? 'POST method)
           (cond [(and (= 5 (length req)) (equal? "venues" (car req)) (equal? "stocks" (caddr req)) (equal? "orders" (fifth req))) (respond (send gm handle-order api-key (cadr req) (caddr req) (hash-copy (string->jsexpr (bytes->string/utf-8 data)))))]
                 [(and (= 7 (length req)) (equal? "venues" (car req)) (equal? "stocks" (caddr req)) (equal? "orders" (fifth req))) (respond (send gm cancel-order api-key (second req) (fourth req) (string->number (sixth req))))]
                 [else (respond/error "unknown request")])]
        [else (respond/error "unknown request")]))

(define (handle-game-master-request req api-key [method 'GET]  #:post-data [data null])
  (cond [(equal? 'GET method) (respond/error "unknown request")]
        [(equal? 'POST method) (cond
                                 [(and (= 2 (length req)) (equal? "levels" (car req))) (respond (send gm new-instance api-key))]
                                 [else (respond/error "unknown request")])]
        [else (respond/error "unknown request")]))

(define (handle-get req api-key)
  (cond [(equal? null req) (display-documentation)]
        [(equal? "favicon.ico" (car req)) (respond/error "no favicon")]
        [(equal? "ob" (car req)) (if (and (not (equal? (cdr req) null))
                                          (equal? (cadr req) "api"))
                                     (handle-orderbook-request (cddr req) api-key)
                                     (respond/error "unknown request"))]
        [(equal? "gm" (car req)) (handle-game-master-request (cdr req) api-key)]
        [else (respond/error "unknown request")]))

(define (handle-post req data api-key)
  (cond [(equal? null req) (display-documentation)]
        [(equal? "ob" (car req)) (if (and (not (equal? (cdr req) null))
                                          (equal? (cadr req) "api"))
                                     (handle-orderbook-request (cddr req) api-key 'POST #:post-data (request-post-data/raw data))
                                     (respond/error "unknown request"))]
        [(equal? "gm" (car req)) (handle-game-master-request (cdr req) api-key 'POST  #:post-data (request-post-data/raw data))]
        [else (respond/error "unknown request")]))

(define (mockfighter-api req)
  (define parts (map path/param-path (url-path (request-uri req))))
  (define auth-hdr (filter (lambda (h) (equal? 'x-starfighter-authorization (car h))) (request-headers req)))
  (define auth-cookie (filter (lambda (h) (equal? 'cookie (car h))) (request-headers req)))
  (define api-key (cond [(and (null? auth-hdr) (null? auth-cookie)) null]
                        [(null? auth-cookie) (cdr (car auth-hdr))]
                        [(null? auth-hdr) (second (string-split (cdr (car auth-cookie)) "="))]))
  (cond [(equal? null api-key) (respond/error "api key required")]
        [(equal? #"GET" (request-method req)) (handle-get parts api-key)]
        [(equal? #"POST" (request-method req)) (handle-post parts req api-key)]
        [(equal? #"DELETE" (request-method req)) (handle-post parts null api-key)]
        [else (respond/error "unknown request")]))
  
(define mockfighter-server%
  (class object% (super-new)
    (init-field prefix port)
    (define/public (serve)
      (serve/servlet mockfighter-api
                     #:port port
                     #:servlet-regexp #rx""
                     #:servlet-path prefix
                     #:command-line? #t))))

(define (run-mockfighter [port 8000])
  (define server (new mockfighter-server% [prefix "/"] [port port]))
  (define server-thread (thread (thunk (send server serve))))
  
  server-thread)
