(define (nr-sqrt x)
  (letrec ((loop (lambda (y)
                   (let ((y-prime (- y (/ (- (* y y) x) (+ y y)))))
                     (if (<= (abs (- y y-prime)) 1e-5)
                         y
                         (loop y-prime))))))
    (loop (- (+ x 1.0) x))))

((derivative nr-sqrt) 4)


#|
(define raw-fol
  (show-time (lambda () (compile-to-fol (dvl-read-file "sqrt.scm")))))

(define hairy-optimal (show-time (lambda () (fol-optimize raw-fol))))

(define done
  (show-time (lambda () (compile-to-scheme (dvl-read-file "sqrt.scm")))))
|#
