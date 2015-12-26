#lang racket
(provide matching-engine%)
(require stockfighter-api "orderbook.rkt" "utils.rkt" racket/generator data/heap)

(define generate-id
  (generator
   ()
   (let loop ([id 0])
     (yield id)
     (loop (+ 1 id)))))

(define matching-engine%
  (class object% (super-new)
    (init-field orderbook)
    (field [orders (make-hash)]
           [next-id 0]
           [last-trade-data (make-hash (list (cons `last 0) (cons `lastSize 0) (cons `lastTrade "")))])
    (define/public (get-orders)  orders)
    (define/public (get-orderbook) orderbook)
    (define/public (get-order-status id)
      (hash-ref orders id (error-json "order not found")))
    
    (define/public (cancel-order id)
      (define order (hash-ref orders id #f))
      (if (equal? #f order)
          (error-json "order not found")
          (begin (hash-set! order `open #f) (hash-set! orders id order) (orderbook-remove! orderbook id) order)))

    (define/public (display)
      (displayln "bids:")
      (print-bids orderbook)
      (displayln "asks:")
      (print-asks orderbook))
    
    (define/public (get-last-trade) last-trade-data)
    
    (define/public (handle-order o)
      (unless (hash-has-key? o `price) (hash-set! o `price 0))
      (hash-set! o `ok #t)
      (hash-set! o `ts (current-time->string))
      (hash-set! o `fills null)
      (hash-set! o `originalQty (order-qty o))
      (hash-set! o `open #t)
      (hash-set! o `id next-id)
      (set! next-id (+ 1 next-id))
      (define type (order-type o))
      (cond [(< (order-price o) 0) (error-json "order price must be non-negative")]
            [(< (order-qty o) 0) (error-json "order size must be non-negative")]
            [(and (not (equal? type "limit")) (not (equal? type "market")) (not (equal? type "fill-or-kill")) (not (equal? type "immediate-or-cancel")))
             (error-json "unknown order type")]
            [(equal? "buy" (order-direction o)) (handle-bid o)]
            [(equal? "sell" (order-direction o)) (handle-ask o)]
            [else (error-json (string-append "unknown order direction, try buy or sell"))]))
    
    (define/public (handle-bid b)
      (hash-set! orders (order-id b) b)
      (define ask-ob (heap->vector (orderbook-asks orderbook)))
      (define ask-depth (vector-sum (vector-map order-qty ask-ob)))
      (cond [(= 0 (heap-count (orderbook-asks orderbook)))
             (cond [(equal? "limit" (order-type b))
                    (orderbook-add-bid! orderbook b) b]
                   [else (hash-set! b `open #f) b])]
            [(and (equal? "market" (order-type b)) (>= ask-depth (order-qty b))) (cross-bid b)]
            [(and (not (equal? "market" (order-type b))) (<= (order-price (orderbook-get-best-ask orderbook)) (order-price b)))
             (cross-bid b)]
            [(equal? "limit" (order-type b)) (orderbook-add-bid! orderbook b) b]
            [else (hash-set! b `open #f)
                  b]))
    
    (define/public (handle-ask a [fok-fills null])
      (hash-set! orders (order-id a) a)
      (define bid-ob (heap->vector (orderbook-bids orderbook)))
      (define bid-depth (vector-sum (vector-map order-qty bid-ob)))
      (cond [(= 0 (heap-count (orderbook-bids orderbook)))
             (cond [(equal? "limit" (order-type a))
                    (orderbook-add-ask! orderbook a) a]
                   [else (hash-set! a `open #f) a])]
            [(and (equal? "market" (order-type a)) (>= bid-depth (order-qty a))) (cross-bid a)]
            [(and (not (equal? "market" (order-type a))) (<= (order-price a) (order-price (orderbook-get-best-bid orderbook))))
             (cross-ask a)]
            [(equal? "limit" (order-type a)) (orderbook-add-ask! orderbook a) a]
            [else (hash-set! a `open #f)
                  a]))
    
    (define/public (cross-ask a [fok-checked? #f])
      (define best-bid (orderbook-get-best-bid orderbook))
      (unless (or (false? best-bid) (void? best-bid))
        (if (and (equal? "fill-or-kill" (order-type a)) (false? fok-checked?))
            (let ([qty 0])
              (for ([bid (in-heap (orderbook-bids orderbook))])
                (when (>= (order-price bid) (order-price a))
                  (set! qty (+ qty (order-qty bid)))))
              (if (>= qty (order-original-qty a))
                  (cross-ask a #t)
                  (begin  (hash-set! a `fills null)
                    (hash-set! a `qty (hash-ref a `originalQty))
                    a)))
            (cond [(= (order-qty best-bid) (order-qty a))
                   (let ([bb (orderbook-remove-best-bid orderbook)])
                     (unless (or (false? bb)  (void? bb))
                       (hash-set! bb `fills (append (order-fills bb) (list (make-hash (list (cons `price (order-price bb))
                                                                                            (cons `qty (order-qty a))
                                                                                            (cons `ts (current-time->string)))))))
                       (hash-set! a `fills (append (hash-ref a `fills null) (list (make-hash (list (cons `price (order-price bb))
                                                                                                   (cons `qty (order-qty bb))
                                                                                                   (cons `ts (current-time->string)))))))
                       (hash-set! last-trade-data `last (order-price bb))
                       (hash-set! last-trade-data `lastSize (order-qty bb))
                       (hash-set! last-trade-data `lastTrade (current-time->string))
                       (hash-set! a `qty 0)
                       (hash-set! bb `qty 0)
                       (hash-set! orders (order-id a) a)
                       (hash-set! orders (order-id bb) bb)
                       (list bb a)))]
                  [(< (order-qty best-bid) (order-qty a))
                   (let* ([bb0 (orderbook-remove-best-bid orderbook)])
                     (unless (or (false? bb0)  (void? bb0))
                       (hash-set! bb0 `fills (append (order-fills bb0) (list (make-hash (list (cons `price (order-price bb0))
                                                                                              (cons `qty (order-qty bb0))
                                                                                              (cons `ts (current-time->string)))))))
                       (hash-set! a `fills (append (hash-ref a `fills null) (list (make-hash (list (cons `price (order-price bb0))
                                                                                                   (cons `qty (order-qty bb0))
                                                                                                   (cons `ts (current-time->string)))))))
                       
                       (hash-set! last-trade-data `last (order-price bb0))
                       (hash-set! last-trade-data `lastSize (order-qty bb0))
                       (hash-set! last-trade-data `lastTrade (current-time->string))
                       (hash-set! a `qty (- (order-qty a) (order-qty bb0)))
                       (hash-set! bb0 `qty 0)
                       (hash-set! bb0 `open #f)
                       (hash-set! orders (order-id a) a)
                       (hash-set! orders (order-id bb0) bb0)
                       (append (list bb0) (handle-ask a))))]
                  [else
                   (let* ([bb0 (orderbook-remove-best-bid orderbook)])
                     (unless (or (false? bb0)  (void? bb0))
                       (hash-set! bb0 `fills (append (order-fills bb0) (list (make-hash (list (cons `price (order-price bb0))
                                                                                              (cons `qty (order-qty a))
                                                                                              (cons `ts (current-time->string)))))))
                       (hash-set! a `fills (append (hash-ref a `fills null) (list (make-hash (list (cons `price (order-price bb0))
                                                                                                   (cons `qty (order-qty a))
                                                                                                   (cons `ts (current-time->string)))))))
                       
                       (hash-set! last-trade-data `last (order-price bb0))
                       (hash-set! last-trade-data `lastSize (order-original-qty a))
                       (hash-set! last-trade-data `lastTrade (current-time->string))
                       (hash-set! bb0 `qty (- (order-qty bb0) (order-qty a)))
                       (hash-set! a `qty 0)
                       (hash-set! a `open #f)
                       (orderbook-add-bid! orderbook bb0)
                       (hash-set! orders (order-id a) a)
                       (hash-set! orders (order-id bb0) bb0)
                       (list a bb0)))]))))

    (define/public (cross-bid b [fok-checked? #f])
      (define best-ask (orderbook-get-best-ask orderbook))
      (unless (or (false? best-ask) (void? best-ask))
        (if (and (equal? "fill-or-kill" (order-type b)) (false? fok-checked?))
            (let ([qty 0])
              (for ([ask (in-heap (orderbook-asks orderbook))])
                (when (<= (order-price ask) (order-price b))
                  (set! qty (+ qty (order-qty ask)))))
              (if (>= qty (order-original-qty b))
                  (cross-bid b #t)
                  (begin (hash-set! b `fills null)
                         (hash-set! b `qty (hash-ref b `originalQty))
                         b)))
            (cond [(= (order-qty best-ask) (order-qty b))
                   (let ([ba (orderbook-remove-best-ask orderbook)])
                     (unless (or (false? ba)  (void? ba))
                       (hash-set! ba `fills (append (order-fills ba) (list (make-hash (list (cons `price (order-price ba))
                                                                                            (cons `qty (order-qty b))
                                                                                            (cons `ts (current-time->string)))))))
                       
                       (hash-set! b `fills (append (hash-ref b `fills null) (list (make-hash (list (cons `price (order-price ba))
                                                                                                   (cons `qty (order-qty ba))
                                                                                                   (cons `ts (current-time->string)))))))
                       
                       (hash-set! last-trade-data `last (order-price ba))
                       (hash-set! last-trade-data `lastSize (order-qty ba))
                       (hash-set! last-trade-data `lastTrade (current-time->string))
                       (hash-set! b `qty 0)
                       (hash-set! ba `qty 0)
                       (hash-set! orders (order-id b) b)
                       (hash-set! orders (order-id ba) ba)
                       (list b best-ask)))]
                  [(< (order-qty best-ask) (order-qty b))
                   (let* ([ba0 (orderbook-remove-best-ask orderbook)])
                     (unless (or (false? ba0)  (void? ba0))
                       
                       (hash-set! ba0 `fills (append (order-fills ba0) (list (make-hash (list (cons `price (order-price ba0))
                                                                                              (cons `qty (order-qty ba0))
                                                                                              (cons `ts (current-time->string)))))))
                       (hash-set! b `fills (append (hash-ref b `fills null) (list (make-hash (list (cons `price (order-price ba0))
                                                                                                   (cons `qty (order-qty ba0))
                                                                                                   (cons `ts (current-time->string)))))))

                       (hash-set! last-trade-data `last (order-price ba0))
                       (hash-set! last-trade-data `lastSize (order-qty ba0))
                       (hash-set! last-trade-data `lastTrade (current-time->string))
                       (hash-set! b `qty (- (order-qty b) (order-qty ba0)))
                       (hash-set! ba0 `open #f)
                       (hash-set! ba0 `qty 0)
                       (hash-set! orders (order-id b) b)
                       (hash-set! orders (order-id ba0) ba0)
                       (append (list ba0) (handle-bid b))))]
                  [else
                   (let ([ba0 (orderbook-remove-best-ask orderbook)])
                     (unless (or (false? ba0)  (void? ba0))
                       (hash-set! b `fills (append (hash-ref b `fills null) (list (make-hash (list (cons `price (order-price ba0))
                                                                                                   (cons `qty (order-qty b))
                                                                                                   (cons `ts (current-time->string)))))))
                       (hash-set! ba0 `fills (append (order-fills ba0) (list (make-hash (list (cons `price (order-price ba0))
                                                                                              (cons `qty (order-qty b))
                                                                                              (cons `ts (current-time->string)))))))
                       

                       (hash-set! last-trade-data `last (order-price ba0))
                       (hash-set! last-trade-data `lastSize (order-original-qty b))
                       (hash-set! last-trade-data `lastTrade (current-time->string))
                       (hash-set! ba0 `qty (- (order-qty ba0) (order-qty b)))
                       (hash-set! b `qty 0)
                       (hash-set! b `open #f)
                       (hash-set! orders (order-id b) b)
                       (hash-set! orders (order-id ba0) ba0)
                       (orderbook-add-ask! orderbook ba0)
                       (list b ba0)))]))))))
          

(module+ test
  (require math)
  (define me (new matching-engine% [orderbook (new-orderbook)]))
  (define order-generator (generator ()
                                     (let loop ([id 0])
                                       (yield (make-hash
                                               (list 
                                                (cons `price (random-integer 100 200))
                                                (cons `orderType "limit")
                                                (cons `fills null)
                                                (cons `venue "IBQEX")
                                                (cons `direction (if (= 1 (random 2)) "buy" "sell"))
                                                (cons `account "IFL33491586")
                                                (cons `qty (random 21)))))
                                               (loop (+ 1 id)))))
   (send me handle-order (make-hash
                         (list
                          (cons `price 1299)
                          (cons `orderType "limit")
                          (cons `fills null)
                          (cons `venue "IBQEX")
                          (cons `direction "sell")
                          (cons `account "IFL33491586")
                          (cons `qty 11))))
   (send me handle-order (make-hash
                         (list
                          (cons `price 1299)
                          (cons `orderType "market")
                          (cons `fills null)
                          (cons `venue "IBQEX")
                          (cons `direction "buy")
                          (cons `account "IFL33491586")
                          (cons `qty 20))))
    (send me handle-order (make-hash
                         (list
                          (cons `price 1299)
                          (cons `orderType "limit")
                          (cons `fills null)
                          (cons `venue "IBQEX")
                          (cons `direction "sell")
                          (cons `account "IFL33491586")
                          (cons `qty 11))))
   (send me handle-order (make-hash
                         (list
                          (cons `price 1299)
                          (cons `orderType "market")
                          (cons `fills null)
                          (cons `venue "IBQEX")
                          (cons `direction "buy")
                          (cons `account "IFL33491586")
                          (cons `qty 20))))
  (send me handle-order (make-hash
                         (list
                          (cons `price 1299)
                          (cons `orderType "limit")
                          (cons `fills null)
                          (cons `venue "IBQEX")
                          (cons `direction "sell")
                          (cons `account "IFL33491586")
                          (cons `qty 11))))
  (send me handle-order (make-hash
                         (list
                          (cons `price 1299)
                          (cons `orderType "fill-or-kill")
                          (cons `fills null)
                          (cons `venue "IBQEX")
                          (cons `direction "buy")
                          (cons `account "IFL33491586")
                          (cons `qty 20))))
  (send me handle-order (make-hash
                         (list
                          (cons `price 1299)
                          (cons `orderType "immediate-or-cancel")
                          (cons `fills null)
                          (cons `venue "IBQEX")
                          (cons `direction "buy")
                          (cons `account "IFL33491586")
                          (cons `qty 20))))
  (send me handle-order (make-hash
                         (list 
                          (cons `price 1299)
                          (cons `orderType "limit")
                          (cons `fills null)
                          (cons `venue "IBQEX")
                          (cons `direction "sell")
                          (cons `account "IFL33491586")
                          (cons `qty 11))))
   (send me handle-order (make-hash
                          (list 
                           (cons `price 1299)
                           (cons `orderType "limit")
                           (cons `fills null)
                           (cons `venue "IBQEX")
                           (cons `direction "sell")
                           (cons `account "IFL33491586")
                           (cons `qty 9))))
  (send me handle-order (make-hash
                         (list 
                          (cons `price 1300)
                          (cons `orderType "limit")
                          (cons `fills null)
                          (cons `venue "IBQEX")
                          (cons `direction "buy")
                          (cons `account "IFL33491586")
                          (cons `qty 20))))
   (send me handle-order (make-hash
                          (list 
                           (cons `price 1300)
                           (cons `orderType "limit")
                           (cons `fills null)
                           (cons `venue "IBQEX")
                           (cons `direction "buy")
                           (cons `account "IFL33491586")
                           (cons `qty 20))))
  (send me handle-order (make-hash
                          (list 
                           (cons `price 1300)
                           (cons `orderType "limit")
                           (cons `fills null)
                           (cons `venue "IBQEX")
                           (cons `direction "buy")
                           (cons `account "IFL33491586")
                           (cons `qty 20))))
   (send me handle-order (make-hash
                          (list 
                           (cons `price 1289)
                           (cons `orderType "limit")
                           (cons `fills null)
                           (cons `venue "IBQEX")
                           (cons `direction "sell")
                           (cons `account "IFL33491586")
                           (cons `qty 5))))
  (send me display)
  (send me get-order-status 6))