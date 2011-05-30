(declare (usual-integrations))

(define-structure
  (closure
   safe-accessors
   (constructor %make-closure)
   (print-procedure
    (simple-unparser-method 'closure
     (lambda (closure)
       (list (closure-exp closure)
             (closure-env closure))))))
  exp
  env)

(define (closure-formal closure)
  (lambda-formal (closure-exp closure)))

(define (closure-body closure)
  (lambda-body (closure-exp closure)))

(define (env-slice env variables)
  (make-env
   (filter (lambda (binding)
             (member (car binding) variables))
           (env-bindings env))))

;;; To keep environments in canonical form, closures only keep the
;;; variables they want.
(define (make-closure exp env)
  (let ((free (free-variables exp)))
    (%make-closure exp (env-slice env free))))

(define-structure
  (bundle
   safe-accessors
   (print-procedure
    (lambda (unparser-state bundle)
      (with-current-unparser-state unparser-state
        (lambda (port)
          (with-output-to-port port
            (lambda ()
              (write (list 'forward (bundle-primal bundle) (bundle-tangent bundle))))))))))
  primal tangent)

(define (object-map f object)
  (cond ((closure? object)
         (make-closure
          (expression-map f (closure-exp object))
          (f (closure-env object))))
        ((env? object)
         (env-map f object))
        ((pair? object)
         (cons (f (car object)) (f (cdr object))))
        ((bundle? object)
         (make-bundle (f (primal object)) (f (tangent object))))
        (else
         object)))

(define (congruent-map f object1 object2 lose)
  (cond ((and (closure? object1) (closure? object2))
         (make-closure
          ;; TODO lose (not error) if expressions not congruent
          (expression-map f (closure-exp object1) (closure-exp object2))
          (f (closure-env object1) (closure-env object2))))
        ((and (env? object1) (env? object2))
         (congruent-env-map f object1 object2 lose))
        ((and (pair? object1) (pair? object2))
         (cons (f (car object1) (car object2))
               (f (cdr object1) (cdr object2))))
        ((and (bundle? object1) (bundle? object2))
         (make-bundle
          (f (primal object1) (primal object2))
          (f (tangent object1) (tangent object2))))
        (else
         (lose))))

(define (expression-map f form . forms)
  (cond ((quoted? form)
         `(quote ,(apply f (cadr form) (map cadr forms))))
        ((constant? form)
         (apply f form forms))
        ((variable? form) form)
        ((pair-form? form)
         (make-pair-form
          (apply expression-map f (car-subform form) (map car-subform forms))
          (apply expression-map f (cdr-subform form) (map cdr-subform forms))))
        ((lambda-form? form)
         (make-lambda-form
          (lambda-formal form)
          (apply expression-map f (lambda-body form) (map lambda-body forms))))
        ((application? form)
         (make-application
          (apply expression-map f (operator-subform form) (map operator-subform forms))
          (apply expression-map f (operand-subform form) (map operand-subform forms))))
        (else
         (error "Invalid expression type" form forms))))

(define (memoize cache f)
  (lambda (x)
    (hash-table/lookup cache x
     (lambda (datum) datum)
     (lambda ()
       (let ((answer (f x)))
         (hash-table/put! cache x answer)
         answer)))))

(define free-variables
  (memoize (make-eq-hash-table)
   (lambda (form)
     (cond ((constant? form)
            '())
           ((variable? form)
            (list form))
           ((pair-form? form)
            (lset-union equal? (free-variables (car-subform form))
                        (free-variables (cdr-subform form))))
           ((lambda-form? form)
            (lset-difference equal? (free-variables (lambda-body form))
                             (free-variables (lambda-formal form))))
           ((pair? form)
            (lset-union equal? (free-variables (car form))
                        (free-variables (cdr form))))
           (else
            (error "Invalid expression type" form forms))))))