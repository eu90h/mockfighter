; An implementation of an order book
#lang racket
(require stockfighter-api data/heap "time.rkt")
(provide (except-out (all-defined-out) order-time))
(define (order-time o) (hash-ref o `ts #f))
(define (order<=? o1 o2)
  (cond [(< (order-price o1) (order-price o2)) #t]
        [(= (order-price o1) (order-price o2)) (date-string<=? (order-time o1) (order-time o2))]
        [else #f]))

(define (order>=? o1 o2)
  (cond [(> (order-price o1) (order-price o2)) #t]
        [(= (order-price o1) (order-price o2)) (date-string<=? (order-time o1) (order-time o2))]
        [else #f]))

(define-struct orderbook (asks bids) #:mutable)
(define (new-orderbook)
  (orderbook (make-heap order<=?) (make-heap order>=?)))
(define (orderbook->jsexpr ob)
  (make-hash (list (cons `bids (vector->list (heap->vector (orderbook-bids ob))))
                   (cons `asks (vector->list (heap->vector (orderbook-asks ob)))))))
; an example result of the get-orderbook api call
(define example #hasheq((symbol . "ADUY")
         (ok . #t)
         (venue . "IBQEX")
         (bids
          .
          (#hasheq((price . 3163) (isBuy . #t) (qty . 354))
           #hasheq((price . 3055) (isBuy . #t) (qty . 1855))
           #hasheq((price . 3040) (isBuy . #t) (qty . 1855))
           #hasheq((price . 3025) (isBuy . #t) (qty . 1855))))
         (asks
          .
          (#hasheq((price . 3178) (isBuy . #f) (qty . 101))
           #hasheq((price . 3193) (isBuy . #f) (qty . 101))
           #hasheq((price . 3208) (isBuy . #f) (qty . 101))))))

(define (orderbook-add-bid! book bid)
  (heap-add! (orderbook-bids book) bid))

(define (orderbook-add-ask! book ask)
  (heap-add! (orderbook-asks book) ask))

(define (orderbook-get-best-bid book)
  (if (= 0 (heap-count (orderbook-bids book)))
      #f
      (heap-min (orderbook-bids book))))

(define (orderbook-remove-best-bid book)
   (if (> (heap-count (orderbook-bids book)) 0)
       (let ([b (heap-min (orderbook-bids book))])
      (heap-remove-min! (orderbook-bids book))
      b)
       #f))

(define (orderbook-get-best-ask book)
  (if (= 0 (heap-count (orderbook-asks book))) #f
    (heap-min (orderbook-asks book))))

(define (orderbook-remove-best-ask book)
  (if (> (heap-count (orderbook-asks book)) 0)
    (let ([a (heap-min (orderbook-asks book))])
      (heap-remove-min! (orderbook-asks book))
      a)
    #f))

(define (orderbook-remove! orderbook id)
  (define o (make-hash))
  (define b (heap-copy (orderbook-bids orderbook)))
  (define newb (make-heap order>=?))
  (for ([order (in-heap/consume! (orderbook-bids orderbook))])
    (if (equal? (hash-ref order `id) id) (set! o order)
      (heap-add! newb order)))
  (define a (heap-copy (orderbook-asks orderbook)))
  (define newa (make-heap order<=?))
  (for ([order (in-heap/consume! (orderbook-asks orderbook))])
    (if (equal? (hash-ref order `id) id) (set! o order)
      (heap-add! newa order)))
  (set-orderbook-asks! orderbook newa)
  (set-orderbook-bids! orderbook newb)
  o)

(define (initialize-orderbook their-book)
  (define our-book (new-orderbook))
  
  (define bid-book (hash-ref their-book `bids))
  (unless (null? bid-book)
    (for ([bid (in-list bid-book)])
      (heap-add! (orderbook-bids our-book) bid)))
  
  (define ask-book (hash-ref their-book `asks))
  (unless (null? ask-book)
    (for ([ask (in-list ask-book)])
      (heap-add! (orderbook-asks our-book) ask)))
  our-book)

(define (print-bids ob)
  (for ([bid (in-heap (orderbook-bids ob))])
    (displayln bid))
  (newline))

(define (print-asks ob)
  (for ([ask (in-heap (orderbook-asks ob))])
    (displayln ask))
  (newline))

;(define ob (initialize-orderbook))
;(for ([bid (in-heap (order-book-bids ob))])
;  (displayln bid))
;(newline)
;  (for ([bid (in-heap (order-book-asks ob))])
;  (displayln bid))
