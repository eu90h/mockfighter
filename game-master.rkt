#lang racket
(require "utils.rkt" "matching-engine.rkt" "venue.rkt"
         json net/rfc6455 stockfighter-api (only-in racket/generator generator yield))
(provide game-master%)
(define generate-id
  (generator
   ()
   (let loop ([id 0])
     (yield id)
     (loop (+ 1 id)))))
(define game-master%
  (class object% (super-new)
    (field [inst #f]
           [stop-sockets null]
           [accounts (make-hash)])
    
    (define (open-websockets)  
      (define (open-ticker-socket c account)
        (if (false? (member account (instance-accounts inst)))
            (error-json "account not registered on this exchange - make a new instance first")
            (hash-set! (instance-ticker-sockets inst) account c)))
      (define (open-executions-socket c account)
        (if (false? (member account (instance-accounts inst)))
            (error-json "account not registered on this exchange - make a new instance first")
            (hash-set! (instance-executions-sockets inst) account c)))
      (define (websocket-handler c state)
        (define parts (string-split
                       (second (string-split (bytes->string/utf-8 (ws-conn-line c)) " "))
                       "/"))
        (cond [(and (= (length parts) 7) (equal? "tickertape" (seventh parts))) (open-ticker-socket c (fourth parts))]
              [(and (= (length parts) 7) (equal? "executions" (seventh parts))) (open-executions-socket c (fourth parts))]
              [(and (= (length parts) 9) (equal? "tickertape" (seventh parts))) (open-ticker-socket c (fourth parts))]
              [(and (= (length parts) 9) (equal? "executions" (seventh parts))) (open-executions-socket c (fourth parts))]))
      (ws-serve #:port 8001
                websocket-handler))
    
     (define (add-account! api-key a)
      (hash-set! accounts api-key a)
      (set-instance-accounts! inst (append (instance-accounts inst) (list a))))
    
    (define (add-bots venue venue-name symbol)
      (define api-key (generate-account-number))
      (define account (generate-account-number))
      (add-account! api-key account)
      (for ([i (in-range 0 10)])
        (send venue add-bot `mm api-key account venue-name symbol))
      (for ([i (in-range 0 20)])
        (send venue add-bot `retail api-key account venue-name symbol))
      (for ([i (in-range 0 30)])
        (send venue add-bot `noise api-key account venue-name symbol))
      (thread (thunk
               (sleep 2)
               (let loop ([trading-day-alarm (alarm-evt (+ (current-milliseconds) 5000))])
                 (if (equal? #f (sync/timeout 0 trading-day-alarm))
                     (begin (run-bots)
                            (change-fmv symbol)
                            (loop trading-day-alarm))
                     (loop (alarm-evt (+ (current-milliseconds) 5000))))))))
    
    (define (init)
      (define venue-name (generate-exchange-name))
      (define venue (new venue% [name venue-name]))
      (define id (generate-id))
      (define symbol (generate-stock-name))
      (send venue add-stock symbol)
      (set! inst (make-instance id null venue venue-name symbol (make-hash) (make-hash)))
      
      (open-websockets)
      (add-bots venue venue-name symbol))
    (init)
   
    (define/public (new-instance api-key)
      (define venue-name (instance-venue-name inst))
      (define account (generate-account-number))
      (add-account! api-key account)
      (define response (make-hash
                        (list (cons 'account account)
                              (cons 'instanceID (instance-id inst))
                              (cons 'tickers (list (instance-symbol inst)))
                              (cons 'venues (list venue-name))
                              (cons 'secondsPerTradingDay 5)
                              (cons 'instructions (hash 'Instructions "Welcome to Mockfighter. Trade away."))
                              (cons 'ok #t))))
      response)
    
    (define (api-key->account key)
      (hash-ref accounts key #f))
    
    (define/public (venue-heartbeat api-key venue-name)
      (make-hash (list (cons `ok (if (equal? #f inst)
                                     #f
                                     (equal? venue-name (instance-venue-name inst)))))))
    
    (define/public (run-bots)
      (if (equal? #f inst)
          (error-json "instance not found")
          (send (instance-venue inst) run-bots)))
    
    (define/public (get-bots)
      (if (equal? #f inst)
          (error-json "instance not found")
          (send (instance-venue inst) get-bots)))
    
    (define/public (change-fmv stock)
      (unless (equal? #f inst)
        (send (instance-venue inst) change-fmv stock)))
    
    (define/public (get-fmv)
      (send (instance-venue inst) get-fmv (instance-symbol inst)))
    
    (define/public (get-order-status api-key venue stock order-id)
        (if (equal? #f inst)
            (error-json "instance not running")
            (if (equal? (send (instance-venue inst) get-name) venue)
                (send (instance-venue inst) get-order-status stock order-id)
                (error-json "venue not found"))))
    
    (define/public (get-quote api-key venue stock)
        (if (equal? #f inst)
            (error-json "instance not running")
            (if (equal? (send (instance-venue inst) get-name) venue)
                (send (instance-venue inst) get-quote stock)
                (error-json "venue not found"))))
    
    (define/public (get-stocks api-key venue)
        (if (equal? #f inst)
            (error-json "instance not running")
            (if (equal? (send (instance-venue inst) get-name) venue)
                (make-hash (list (cons `ok #t) (cons `symbols (list (make-hash (list (cons `name (string-append (instance-symbol inst) " Co."))
                                                                                     (cons `symbol (instance-symbol inst))))))))
                (error-json "venue not found"))))
    
    (define/public (get-orderbook api-key venue stock)
        (if (equal? #f inst)
            (error-json "instance not running")
            (if (equal? (send (instance-venue inst) get-name) venue)
                (send (instance-venue inst) get-orderbook stock)
                (error-json "venue not found"))))
    
    (define (send-quote ticker account inst q)
      (unless (false? ticker)
        (if (ws-conn-closed? ticker)
            (hash-set! (instance-ticker-sockets inst) account #f)
            (with-handlers ([exn? (lambda (e) (hash-set! (instance-ticker-sockets inst) account #f))])
              (ws-send! ticker (jsexpr->string q))))))
    
    
    
    (define/public (cancel-order api-key venue stock order-id)
        (if (equal? #f inst)
            (error-json "instance not running")
            (if (equal? (instance-venue-name inst) venue)
                (if (false? (api-key->account api-key))
                    (error-json "account not registered on this venue")
                    (let ([response (send (instance-venue inst) cancel-order inst stock order-id (api-key->account api-key))])
                      (when (and (hash? response) (ok? response))
                      (for ([(key accnt) (in-hash accounts)])
                        (when (hash-has-key? (instance-ticker-sockets inst) accnt)
                        (define ticker (hash-ref (instance-ticker-sockets inst) accnt #f))
                        (unless (or (equal? #f ticker) (not (ok? response)))
                          (send-quote ticker accnt inst (make-hash (list (cons `ok #t)
                                                                         (cons `quote (send (instance-venue inst) get-quote (instance-symbol inst))))))))))
                      response))
                (error-json "venue not found"))))
    
    (define/public (handle-order api-key venue stock order)
      (define account (hash-ref order `account #f))
      (cond [(equal? #f account) (error-json "order missing account number")]
            [else 
                    (if (equal? #f inst)
                        (error-json "instance not running")
                        (let ([venue-name (hash-ref order `venue #f)])
                          (if (or (equal? #f venue-name) (not (equal? (instance-venue-name inst) venue-name)))
                              (error-json "venue not found")
                              (if (false? (api-key->account api-key))
                                  (error-json "account not registered on this venue")
                                  (let ([response (send (instance-venue inst) handle-order inst order)])
                                    (when (and (hash? response) (ok? response))
                                    (for ([(key accnt) (in-hash accounts)])
                                      (when (hash-has-key? (instance-ticker-sockets inst) accnt)
                                      (define ticker (hash-ref (instance-ticker-sockets inst) accnt #f))
                                      (unless (or (equal? #f ticker) (not (ok? response)))
                                        (send-quote ticker accnt inst (make-hash (list (cons `ok #t)
                                                                                       (cons `quote (send (instance-venue inst) get-quote (instance-symbol inst))))))))))
                                 
                                        (if (hash? response) response order))))))]))))