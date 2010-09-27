(let ((double (lambda (x)
		(+ x x)))
      (square (lambda (x)
		(* x x)))
      (compose (lambda (f g)
		 (lambda (x) (f (g x))))))
  (cons ((compose double square) (real 2))
	((compose square double) (real 2))))

(let ((addn (lambda (n)
	      (lambda (x)
		(+ n x)))))
  (let ((add5 (addn (real 5))))
    (add5 (real 3))))

(let ((cube (lambda (x)
	      (* x (* x x)))))
  (let ((enlarge-upto (lambda (bound)
			(lambda (x)
			  (if (< x bound)
			      (cube x)
			      x)))))
    ((enlarge-upto (real 20)) (real 3))))

(let ((my-add (lambda (x y)
		(+ x y))))
  (my-add (real 3) (real 6)))

(let ((my-add (lambda (foo)
		(+ foo))))
  (my-add (cons (real 3) (real 6))))

(let ((my-add (lambda (foo)
		(+ foo))))
  (my-add (cons 3 (real 6))))

(let ((delay-add (lambda (x y)
		(lambda ()
		  (+ x y)))))
  ((delay-add (real 3) (real 6))))

(let ((cube (lambda (x)
	      (* x (* x x)))))
  (let ((enlarge-upto (lambda (bound)
			(lambda (x)
			  (if (< x bound)
			      (cube x)
			      x)))))
    ((enlarge-upto (real 20)) (real 3))))

(if (< 3 6)
    (real 4)
    (real 3))

(letrec ((fact (lambda (n)
		 (if (= n 1)
		     1
		     (* n (fact (- n 1)))))))
  (fact 5))

(let ((Z (lambda (f)
	   ((lambda (x)
	      (f (lambda (y)
		   ((x x) y))))
	    (lambda (x)
	      (f (lambda (y)
		   ((x x) y))))))))
  (let ((fact (Z (lambda (fact)
		   (lambda (n)
		     (if (= n 1)
			 1
			 (* n (fact (- n 1)))))))))
    (fact 5)))

(let ((increment (lambda (x) (+ x 1)))
      (double (lambda (x) (* x 2)))
      (car (lambda ((cons x y)) x))
      (cdr (lambda ((cons x y)) y)))
  (letrec ((map (lambda (f lst)
		  (if (null? lst)
		      '()
		      (cons (f (car lst)) (map f (cdr lst)))))))
    (cons (map increment 1 2 3 '())
	  (map double 4 5 '()))))

(letrec ((even? (lambda (n)
		  (if (= n 0)
		      #t
		      (odd? (- n 1)))))
	 (odd? (lambda (n)
		 (if (= n 0)
		     #f
		     (even? (- n 1))))))
  (even? (real 5)))

(let loop ((count (real 0)))
  (if (< count 10)
      (loop (+ count 1))
      count))