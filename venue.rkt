#lang racket
(require "matching-engine.rkt" "orderbook.rkt" stockfighter-api "utils.rkt"
         "noise-trader.rkt" "mm.rkt" math)
(provide venue%)
(define (error-json msg)
  (make-hash (list (cons `ok #f) (cons `error msg))))
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
      (hash-set! stocks name (new matching-engine% [orderbook (new-orderbook)]))
      (hash-set! fmvs name (random-integer 1000 10000)))
    
    (define/public (cancel-order symbol id)
      (define me (hash-ref stocks symbol #f))
      (if (equal? me #f)
          (error-json "symbol not found on exchange")
          (send me cancel-order id)))
    
    (define/public (get-fmv stock)
      (hash-ref fmvs stock #f))
    
    (define/public (change-fmv stock)
      (define fmv (hash-ref fmvs stock #f))
      (define change (* (if (= 1 (random 2)) -1 1) (random-integer 20 500)))
      (hash-set! fmvs stock (+ fmv change)))
    
    (define/public (run-bots)
      (for ([bot (in-list bots)])
        (send bot trade)))
    
    (define/public (add-bot type account venue-name symbol)
      (define bot (cond
        [(equal? type `mm) (new mm% [api-key (generate-account-number)]
                                [account account]
                                [stock symbol]
                                [venue-name venue-name]
                               [venue this])]
        [(equal? type `noise) (new noise-trader% [api-key (generate-account-number)]
                                [account account]
                                [stock symbol]
                                [venue-name venue-name]
                               [venue this])]))
      (set! bots (append bots (list bot)))
      bot)
    
    (define/public (handle-order order)
      (define symbol (hash-ref order `symbol #f))
      (if (eq? #f symbol)
          (error-json "symbol not found")
          (let ([me (hash-ref stocks symbol #f)])
            (if (eq? #f me)
                (error-json "symbol not found on exchange")
                (send me handle-order order)))))
    
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
          (error-json "symbol nor found on exchange")
          (let* ([ob (send me get-orderbook)])
            (define bb (let ([o (orderbook-get-best-bid ob)])
                         (if (false? o) (make-hash) o)))
            (define ba (let ([o (orderbook-get-best-ask ob)])
                         (if (false? o) (make-hash) o)))
           
            (define bid (hash-ref bb `price 0))
            (define ask (hash-ref ba `price 0))
            (define bid-size (hash-ref bb `qty 0))
            (define ask-size (hash-ref ba `qty 0))
            (make-hash (list (cons `ok #t) (cons `symbol stock) (cons `venue name) (cons `bid bid) (cons `ask ask)
                             (cons `bidSize bid-size) (cons `askSize ask-size) (cons `quoteTime (current-time->string)))))))))