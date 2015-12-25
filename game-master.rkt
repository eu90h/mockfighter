#lang racket
(require "utils.rkt" "matching-engine.rkt" "orderbook.rkt" "venue.rkt"
         json math net/rfc6455 stockfighter-api racket/generator)
(provide game-master% (struct-out instance))
(define-struct instance (id owner data venue venue-name symbol ticker-socket executions-socket) #:mutable)
(define generate-id
  (generator
   ()
   (let loop ([id 0])
     (yield id)
     (loop (+ 1 id)))))
(define game-master%
  (class object% (super-new)
    (field [instances (make-hash)]
           [stop-sockets null])
    
    (define (open-websockets api-key venue-name account symbol)
      (define ticker-tape-url-2 (string-append "/ob/api/ws/" account "/venues/" venue-name "/tickertape/stocks/" symbol))
      (define ticker-tape-url (string-append "/ob/api/ws/" account "/venues/" venue-name "/tickertape"))
      (define executions-url (string-append "/ob/api/ws/" account "/venues/" venue-name "/executions"))
      (define executions-url-2 (string-append "/ob/api/ws/" account "/venues/" venue-name "/executions/stocks/" symbol))     
      (define (execution-connection-handler c)
        (set-instance-executions-socket! (hash-ref instances api-key) c))
      (define (ticker-connection-handler c)
        (set-instance-ticker-socket! (hash-ref instances api-key) c))
      (set! stop-sockets
            (ws-serve* #:port 8001
                       (ws-service-mapper
                        [ticker-tape-url
                         [(#f) ticker-connection-handler]]
                        [ticker-tape-url-2
                         [(#f) ticker-connection-handler]]
                        [executions-url
                         [(#f) execution-connection-handler]]
                        [executions-url-2
                         [(#f) execution-connection-handler]]))))
    
    (define (add-bots api-key account venue venue-name symbol)
      (for ([i (in-range 0 10)])
        (send venue add-bot `mm (generate-account-number) venue-name symbol))
      (for ([i (in-range 0 100)])
        (send venue add-bot `noise (generate-account-number) venue-name symbol))
      (for ([i (in-range 0 30)])
        (send venue add-bot `noise (generate-account-number) venue-name symbol))
      (thread (thunk
               (sleep 2)
               (define bots (get-bots api-key))
               (for ([bot (in-list bots)])
                 (send bot set-api-key api-key))
               (let loop ([trading-day-alarm (alarm-evt (+ (current-milliseconds) 5000))])
                 (if (equal? #f (sync/timeout 0 trading-day-alarm))
                     (begin (run-bots api-key)
                            (change-fmv api-key symbol)
                            (loop trading-day-alarm))
                     (loop (alarm-evt (+ (current-milliseconds) 5000))))))))
    
    (define/public (new-instance api-key)
      (define venue-name (generate-exchange-name))
      (define venue (new venue% [name venue-name]))
      (define account (generate-account-number))
      (define symbol (generate-stock-name))
      (define id (generate-id))
      (define response (hash 'account account
                             'instanceID id
                             'tickers (list symbol)
                             'venues (list venue-name)
                             'secondsPerTradingDay 5
                             'instructions (hash 'Instructions "Welcome to Mockfighter. Trade away.")
                             'ok #t))
      (hash-set! instances api-key (instance id account response venue venue-name symbol #f #f))
      (send venue add-stock symbol)
      (open-websockets api-key venue-name account symbol)
      (add-bots api-key account venue venue-name symbol)
      response)

    (define/public (venue-heartbeat api-key venue-name)
      (define instance (hash-ref instances api-key #f))
      (make-hash (list (cons `ok (if (equal? #f instance)
                                     #f
                                     (equal? venue-name (instance-venue-name instance)))))))
    
    (define/public (get-instances)
      (hash-keys instances))
    
    (define/public (get-instance-data)
      instances)
    
    (define/public (run-bots api-key)
      (define instance (hash-ref instances api-key #f))
      (if (equal? #f instance)
          (error-json "instance not found")
          (send (instance-venue instance) run-bots)))
    
    (define/public (get-bots api-key)
      (define instance (hash-ref instances api-key #f))
      (if (equal? #f instance)
          (error-json "instance not found")
          (send (instance-venue instance) get-bots)))
    
    (define/public (change-fmv api-key stock)
      (define instance (hash-ref instances api-key #f))
      (unless (equal? #f instance)
        (send (instance-venue instance) change-fmv stock)))
    
    (define/public (get-fmv api-key)
      (send (hash-ref instances api-key #f) get-fmv (instance-symbol (hash-ref instances api-key #f))))
    
    (define/public (get-order-status api-key venue stock order-id)
      (let ([instance (hash-ref instances api-key #f)])
        (if (equal? #f instance)
            (error-json "instance not running")
            (if (equal? (send (instance-venue (hash-ref instances api-key)) get-name) venue)
                (send (instance-venue instance) get-order-status stock order-id)
                (error-json "venue not found")))))
    
    (define/public (get-quote api-key venue stock)
      (let ([instance (hash-ref instances api-key #f)])
        (if (equal? #f instance)
            (error-json "instance not running")
            (if (equal? (send (instance-venue (hash-ref instances api-key)) get-name) venue)
                (send (instance-venue instance) get-quote stock)
                (error-json "venue not found")))))
    
    (define/public (get-stocks api-key venue)
       (let ([instance (hash-ref instances api-key #f)])
        (if (equal? #f instance)
            (error-json "instance not running")
            (if (equal? (send (instance-venue (hash-ref instances api-key)) get-name) venue)
                (make-hash (list (cons `ok #t) (cons `symbols (list (make-hash (list (cons `name (string-append (instance-symbol instance) " Co."))
                                                                                     (cons `symbol (instance-symbol instance))))))))
                (error-json "venue not found")))))
    
    (define/public (get-orderbook api-key venue stock)
       (let ([instance (hash-ref instances api-key #f)])
        (if (equal? #f instance)
            (error-json "instance not running")
            (if (equal? (send (instance-venue (hash-ref instances api-key)) get-name) venue)
                (send (instance-venue (hash-ref instances api-key)) get-orderbook stock)
                (error-json "venue not found")))))
    
    (define (send-quote api-key instance q)
      (define ticker (instance-ticker-socket instance))
      (if (ws-conn-closed? ticker)
          (set-instance-ticker-socket! instance #f)
          (with-handlers ([exn? (lambda (e) (set-instance-ticker-socket! instance #f))])
            (ws-send! ticker (jsexpr->string q)))))
    
    (define (send-execution api-key instance e)
      (define executions (instance-executions-socket instance))
      (if (ws-conn-closed? executions)
          (set-instance-executions-socket! instance #f)
          (with-handlers ([exn? (lambda (e) (set-instance-executions-socket! instance #f))])
            (ws-send! executions (jsexpr->string e)))))
    
    (define/public (cancel-order api-key venue stock order-id)
      (let ([instance (hash-ref instances api-key #f)])
        (if (equal? #f instance)
            (error-json "instance not running")
            (if (equal? (send (instance-venue (hash-ref instances api-key)) get-name) venue)
                (let ([response (send (instance-venue instance) cancel-order stock order-id)]
                      [ticker (instance-ticker-socket instance)])
                  (handle-executions api-key instance response)
                  (unless (equal? #f ticker)
                    (send-quote api-key instance (make-hash (list (cons `ok #t)
                                                                  (cons `quote (send (instance-venue instance) get-quote (instance-symbol instance)))))))
                  response)
                (error-json "venue not found")))))
    
    (define (is-players-order? instance order)
      (equal? (order-account order) (instance-owner instance)))
    
    (define (handle-executions api-key instance response)
      (define executions (instance-executions-socket instance))
      (unless (equal? #f executions)
        (cond [(list? response)
               (let ([users-orders (filter (lambda (o) (is-players-order? instance o)) response)])
                 (unless (null? users-orders)
                   (for ([order (in-list users-orders)])
                     (when (or (equal? #f (order-open? response)) (not (null? (order-fills response))))
                       (send-execution api-key instance (make-hash (list (cons `ok #t)
                                                                         (cons `order order))))))))]
              [(hash? response)
               (when (is-players-order? instance response)
                 (when (or (equal? #f (order-open? response))
                           (equal? #f (null? (order-fills response))))
                   (send-execution api-key instance (make-hash (list (cons `ok #t)
                                                                     (cons `order response))))))])))
    
    (define/public (handle-order api-key venue stock order)
      (define account (hash-ref order `account #f))
      (cond [(equal? #f account) (error-json "order missing account number")]
            [else (let ([instance (hash-ref instances api-key #f)])
                    (if (equal? #f instance)
                        (error-json "instance not running")
                        (let ([venue-name (hash-ref order `venue #f)])
                          (if (or (equal? #f venue-name) (not (equal? (send (instance-venue (hash-ref instances api-key)) get-name) venue-name)))
                              (error-json "venue not found")
                              (let ([response (send (instance-venue instance) handle-order order)]
                                    [ticker (instance-ticker-socket instance)])
                                (unless (equal? #f ticker)
                                  (send-quote api-key instance (make-hash (list (cons `ok #t)
                                                                        (cons `quote (send (instance-venue instance) get-quote (instance-symbol instance)))))))
                                (handle-executions api-key instance response)
                                response)))))]))))
(module+ test
  (define gm (new game-master%))
  (define data (send gm new-instance "1234"))
  data
  (send gm handle-order (make-hash
                          (list 
                           (cons `price 1289)
                           (cons `orderType "limit")
                           (cons `fills null)
                           (cons `venue "IBQEX")
                           (cons `direction "sell")
                           (cons `account "IFL33491586")
                           (cons `qty 5))))
  (send gm handle-order (make-hash
                          (list
                           (cons `symbol (hash-ref data `symbol))
                           (cons `price 1289)
                           (cons `orderType "limit")
                           (cons `fills null)
                           (cons `venue (hash-ref data `venue))
                           (cons `direction "sell")
                           (cons `account (hash-ref data `account))
                           (cons `qty 5)))))