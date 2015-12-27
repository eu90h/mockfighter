#lang racket
(provide generate-account-number generate-exchange-name generate-stock-name error-json
         respond respond/error vector-sum (struct-out instance))
(require web-server/servlet json math)

(define-struct instance (id accounts venue venue-name symbol ticker-sockets executions-sockets) #:mutable)

(define (respond jsexpr)
  (unless (jsexpr? jsexpr)
    (raise-argument-error `respond "jsexpr?" jsexpr))
  (response
   200                 ; response code
   #"OK"               ; response message
   (current-seconds)   ; timestamp
   TEXT/HTML-MIME-TYPE ; MIME type for content
   '()                 ; additional headers
   
   ; the following parameter accepts the output port
   ; to which the page should be rendered.
   (lambda (client-out)
     (write-string (jsexpr->string jsexpr) client-out))))

(define (respond/error msg)
  (respond (make-hash (list (cons `ok #f) (cons `error msg)))))

(define id-symbol-table (list->vector (map (lambda (x) (string-ref x 0)) (list "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P"
                              "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z" "0" "1" "2" "3" "4"
                              "5" "6" "7" "8" "9"))))
(define consonants #(#\B #\C #\D #\F #\G #\H #\J #\K #\L #\M #\N #\P #\Q #\R #\S #\T #\V #\W #\X #\Z))
(define vowels #(#\A #\E #\I #\O #\U #\Y))
(define (generate-account-number)
  (build-string 11 (lambda (x) (vector-ref id-symbol-table (random 36)))))

(define (generate-exchange-name)
  (string-append (build-string 3
            
                  (lambda (n) (if (= n 1) (vector-ref vowels (random 6))
                                  (vector-ref consonants (random 20))))) "EX"))

(define (generate-stock-name)
  (build-string (random-integer 3 4)
                (lambda (n) (vector-ref consonants (random 20)))))

(define (error-json msg)
  (make-hash (list (cons `ok #f) (cons `error msg))))

 (define (vector-sum v)
      (foldl + 0 (vector->list v)))