(define (macroexpand exp)
  (cond ((variable? exp)
	 exp)
	((null? exp)
	 '())
	((pair? exp)
	 (cond ((eq? (car exp) 'lambda)
		`(lambda ,(macroexpand-formals (cadr exp))
		   ,(macroexpand (caddr exp))))
	       ((eq? (car exp) 'cons)
		`(cons ,(macroexpand (cadr exp))
		       ,(macroexpand (caddr exp))))
	       ((flow-macro? exp)
		(macroexpand (expand-flow-macro exp)))
	       (else
		`(,(macroexpand (car exp))
		  ,(macroexpand-operands (cdr exp))))))
	(else
	 (error "Invalid expression syntax" exp))))

(define (macroexpand-operands operands)
  (if (null? operands)
      '()
      `(cons ,(macroexpand (car operands))
	     ,(macroexpand-operands (cdr operands)))))

(define (macroexpand-formals formals)
  (cond ((null? formals)
	 formals)
	((symbol? formals)
	 formals)
	((pair? formals)
	 (if (eq? (car formals) 'cons)
	     (cons (macroexpand-formals (cadr formals))
		   (macroexpand-formals (caddr formals)))
	     (cons (macroexpand-formals (car formals))
		   (macroexpand-formals (cdr formals)))))
	(else
	 (error "Invalid formal parameter tree" formals))))

(define *flow-macros* '())

(define (flow-macro? form)
  (memq (car form) (map car *flow-macros*)))

(define (expand-flow-macro form)
  (let ((transformer (assq (car form) *flow-macros*)))
    (if transformer
	((cdr transformer) form)
	(error "Undefined macro" form))))

(define (define-flow-macro! name transformer)
  (set! *flow-macros* (cons (cons name transformer) *flow-macros*)))

(define-flow-macro! 'let
  (lambda (form)
    (let ((bindings (cadr form))
	  (body (cddr form)))
      `((lambda ,(map car bindings)
	  ,@body)
	,@(map cadr bindings)))))