#lang racket
(require "matching-engine.rkt" "orderbook.rkt" stockfighter-api "utils.rkt"
         "noise-trader.rkt" "mm.rkt" math data/heap "retail-trader.rkt")
(provide venue%)

(define venue%
  (class object% (super-new)
    (init-field name)
    (field [stocks (make-hash)]
           [fmvs (make-hash)]
           [bots (list)])
    (define/public (get-name) name)
    (define/public (get-stocks) (hash-keys stocks))
    (define/public (get-bots) bots)
    (define/public (add-stock name)
      (if (string? name)
          (begin (hash-set! stocks name (new matching-engine% [orderbook (new-orderbook)]))
                 (hash-set! fmvs name (random-integer 1000 10000)))
          (error-json "invalid stock name")))
    
    (define/public (cancel-order inst symbol id account)
      (define me (hash-ref stocks symbol #f))
      (if (equal? me #f)
          (error-json "symbol not found on exchange")
          (send me cancel-order inst id account)))
    
    (define/public (get-fmv stock)
      (hash-ref fmvs stock #f))
    
    (define/public (change-fmv stock)
      (define fmv (hash-ref fmvs stock #f))
      (if (equal? fmv #f)
          (error-json "stock fmv not found")
          (let ([change (* (if (= 1 (random 2)) -1 1) (if (= 1 (random-integer 1 30))
                                                          (random-integer 20 100)
                                                          (random-integer 1 25)))])
            (hash-set! fmvs stock (+ fmv change)))))
    
    (define/public (run-bots)
      (unless (equal? null bots)
        (for ([bot (in-list bots)])
          (send bot trade))))
    
    (define/public (add-bot type api-key account venue-name symbol)
      
      (define bot (cond
                    [(equal? type `retail) (new retail-trader% [api-key api-key]
                                                [venue-name venue-name]
                                                [stock symbol]
                                                [account account]
                                                [venue this])]
                    [(equal? type `mm) (new mm% [api-key api-key]
                                                [venue-name venue-name]
                                                [stock symbol]
                                                [account account]
                                                [venue this])]
                    [(equal? type `noise) (new noise-trader% [api-key api-key]
                                                [venue-name venue-name]
                                                [stock symbol]
                                                [account account]
                                                [venue this])]))
      (set! bots (append bots (list bot)))
      bot)
    
    (define/public (handle-order inst order)
      (define symbol (hash-ref order `symbol #f))
      (if (equal? #f symbol)
          (error-json "symbol not found")
          (let ([me (hash-ref stocks symbol #f)])
            (if (equal? #f me)
                (error-json "symbol not found on exchange")
                (if (integer? (order-price order))
                    (send me handle-order inst order)
                    (error-json "price must be an integer"))))))
    
    (define/public (get-orderbook stock)
      (define me (hash-ref stocks stock #f))
      (if (equal? me #f)
          (error-json "symbol not found on exchange")
          (let ([orderbook (send me get-orderbook)])
            (if (orderbook? orderbook)
                (orderbook->jsexpr orderbook)
                (error-json "error getting orderbook")))))
    
    (define/public (get-order-status stock order-id)
      (define me (hash-ref stocks stock #f))
      (if (equal? me #f)
          (error-json "symbol not found on exchange")
          (send me get-order-status order-id)))
    
    (define/public (get-quote stock)
      (define me (hash-ref stocks stock #f))
      (if (equal? me #f)
          (error-json "symbol not found on exchange")
          (let* ([ob (send me get-orderbook)])
            (define bb (let ([o (orderbook-get-best-bid ob)])
                         (if (false? o) (make-hash) o)))
            (define ba (let ([o (orderbook-get-best-ask ob)])
                         (if (false? o) (make-hash) o)))
            (define bid (hash-ref bb `price 0))
            (define ask (hash-ref ba `price 0))
            (define bid-size (hash-ref bb `qty 0))
            (define ask-size (hash-ref ba `qty 0))
            (define bid-depth (if (= 0 bid) 0
                                  (with-handlers ([exn? (lambda (e) 0)])
                                    (vector-sum (vector-map order-qty (heap->vector (orderbook-bids ob)))))))
            (define ask-depth (if (= 0 ask) 0
                                  (with-handlers ([exn? (lambda (e) 0)])
                                    (vector-sum (vector-map order-qty (heap->vector (orderbook-asks ob)))))))
            (define last-trade-data (send me get-last-trade))
           (define q (make-hash (list (cons `ok #t) (cons `symbol stock) (cons `venue name)
                             (cons `bidSize bid-size) (cons `askSize ask-size) (cons `quoteTime (current-time->string))
                             (cons `bidDepth bid-depth) (cons `askDepth ask-depth) (cons `last (hash-ref last-trade-data `last))
                             (cons `lastSize (hash-ref last-trade-data `lastSize)) (cons `lastTrade (hash-ref last-trade-data `lastTrade)))))
            (unless (= 0 bid) (hash-set! q `bid bid))
            (unless (= 0 ask) (hash-set! q `ask ask))
            q)))))