(load-relative "../../testing/load")
(load-relative "../../vl/test/utils")

(define (in-and-loop expression)
  `(let ((x (gensym)))
     (let loop ((count (real 10))
                (answer #t))
       (if (= count 0)
           answer
           (loop (- count 1) (and answer ,expression))))))

(define (in-frobnicating-loop expression)
  `(let ((x (gensym)))
     (define (frobnicate symbol)
       (if (> (real 2) 1)
           symbol
           x))
     (let loop ((count (real 10))
                (answer #t))
       (if (= count 0)
           answer
           (loop (- count 1) (and answer ,expression))))))

(in-test-group
 dvl
 (define-each-check
   (equal? 3 (determined-answer '(+ 1 2)))
   (equal? #f (determined-answer '(gensym= (gensym) (gensym))))
   (equal? #t (determined-answer '(let ((x (gensym))) (gensym= x x))))
   (equal? #f (determined-answer '(let ((x (gensym))) (gensym= x (gensym)))))

   (equal? #t
    (union-free-answer
     '(let ((x (gensym)))
        (gensym= x (if (> (real 2) (real 1)) x (gensym))))))

   (equal? #f
    (union-free-answer
     '(let ((x (gensym)))
        (gensym= x (if (< (real 2) (real 1)) x (gensym))))))

   (equal? #f
    (union-free-answer
     '(let ((x (gensym)))
        ;; The analysis could solve this with more accurate modeling
        ;; of possible gensym values
        (gensym= (gensym) (if (< (real 2) (real 1)) x (gensym))))))

   (equal?
    '(if (= (real 10) 0)
         #t
         #f)
    (compile-to-scheme
     (in-and-loop '(gensym= (gensym) (gensym)))))

   (equal? #t
    (union-free-answer
     (in-and-loop '(gensym= x (if (> (real 2) (real 1)) x (gensym))))))

   (equal? #f
    (union-free-answer
     (in-and-loop '(gensym= x (if (< (real 2) (real 1)) x (gensym))))))

   (equal? #f
    (union-free-answer
     (in-and-loop '(gensym= (gensym) (if (< (real 2) (real 1)) x (gensym))))))

   (equal? #f
    (union-free-answer
     (in-and-loop '(gensym= (gensym) (if (> (real 2) (real 1)) x (gensym))))))

   ;; TODO These two break the analysis because it replicates the loop
   ;; body for every different gensym it might be passed.
   #;
   (let ((x (gensym)))
     (gensym= x
      (let loop ((count (real 10))
                 (y (gensym)))
        (if (= count 0)
            (if (< (real 2) 1)
                x
                y)
            (loop (- count 1) (gensym))))))
   #;
   (let ((x (gensym)))
     (gensym= x
      (let loop ((count (real 10))
                 (y (gensym)))
        (if (= count 0)
            (if (< (real 2) 1)
                x
                y)
            (loop (- count 1) (if (> (real 2) 1) (gensym) y))))))

   (equal? #f
    (union-free-answer
     (in-frobnicating-loop '(gensym= x (frobnicate (gensym))))))

   (equal? #t
    (union-free-answer ;; TODO Actually determined, except for sweeping out dead cruft
     (in-frobnicating-loop '(gensym= x (frobnicate x)))))

   (equal? #t
    (union-free-answer
     (in-frobnicating-loop '(let ((y (gensym)))
                              (gensym= y (frobnicate y))))))

   (equal? #f
    (union-free-answer
     (in-frobnicating-loop '(let ((y (gensym)))
                              (gensym= y (frobnicate (gensym)))))))

   (equal? '(if (= (real 10) 0)
                #t
                #f)
    (compile-to-scheme
     (in-frobnicating-loop '(let ((y (gensym)))
                              (let ((z (gensym)))
                                (gensym= z (frobnicate y)))))))
   )

 (for-each-example "../vl/examples.scm" define-union-free-example-test)
 (for-each-example "../vl/test/test-vl-programs.scm"
                   define-union-free-example-test)

 (define-test (tangent-of-function)
   (check (equal? 1 (fast-union-free-answer
                     (dvl-prepare
                      '(let ()
                         (define (adder n)
                           (lambda (x)
                             (g:+ x n)))
                         (((derivative adder) (real 3)) (real 4))))))))

 ;; TODO Make compiling the essential examples acceptably fast
 #;
 (for-each-example "../slad/essential-examples.scm"
  (lambda (program #!optional value)
    (define-fast-union-free-example-test
      (dvl-prepare (vlad->dvl program)) value)))

 (define-test (executable-entry-point)
   (check
    (equal?
     ".2500002594080783\n"
     (with-output-to-string
       (lambda ()
         (dvl-run-file "sqrt.scm"))))))
 )
