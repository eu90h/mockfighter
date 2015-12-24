#lang racket
(require stockfighter-api data/heap)
(provide (all-defined-out))

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

(define (print-bids ob)
  (for ([bid (in-heap (orderbook-bids ob))])
    (displayln bid))
  (newline))

(define (print-asks ob)
  (for ([ask (in-heap (orderbook-asks ob))])
    (displayln ask))
  (newline))
