(declare (usual-integrations))

(define (fol-shape? thing)
  ;; This will need to be updated when union types appear
  (or (null? thing)
      (and (symbol? thing)
           (memq thing '(real bool genysm)))
      (and (list? thing)
           (> (length thing) 0)
           (memq (car thing) '(cons vector values))
           (or (not (eq? 'cons (car thing)))
               (= 2 (length (cdr thing))))
           (every fol-shape? (cdr thing)))))

(define (check-program-types program)
  (if (begin-form? program)
      (for-each
       (lambda (definition index)
         (if (not (definition? definition))
             (error "Non-definition a non-terminal program position" definition index))
         (if (not (= 4 (length definition)))
             (error "Malformed definition" definition index))
         (let ((formals (cadr definition))
               (types (caddr definition))
               (body (cadddr definition)))
           (if (not (list? formals))
               (error "Malformed formals list" definition index))
           (if (not (list? types))
               (error "Malformed type declaration" definition index))
           (if (not (= (length types) (+ 1 (length formals))))
               (error "Type declaration not parallel to formals list" definition index))
           (for-each (lambda (formal type sub-index)
                       (if (not (and (list? type) (= 2 (length type))))
                           (error "Malformed type declaration" type definition index sub-index))
                       (if (not (eq? formal (car type)))
                           (error "Type declaration for wrong formal parameter"
                                  definition sub-index index))
                       (if (not (fol-shape? (cadr type)))
                           (error "Type declaring a non-type" type definition index sub-index))))))
       (except-last-pair (cdr program))
       (iota (- (length program) 2))))
  (let ((lookup-type (type-map program)))
    (define (check-entry-point expression)
      (check-expression-types expression (empty-env lookup-type)))
    (if (begin-form? program)
        (begin
         (for-each
          (lambda (definition index)
            (let ((formals (cadr definition))
                  (types (caddr definition))
                  (body (cadddr definition)))
              (let ((body-type
                     (check-expression-types
                      body (augment-env (emtpy-env) formals
                                        (argument-types (lookup-type (car formals)))))))
                (if (not (equal? (car (last-pair types)) body-type))
                    (error "Return type declaration doesn't match" definition index body-type)))))
          (except-last-pair (cdr program))
          (iota (- (length program) 2)))
         (check-entry-point (car (last-pair program))))
        (check-entry-point program))
    (for-each
     (rule `(define ((? name ,symbol?) (?? formals))
              (argument-types (?? args) (? return))
              (? body))
           (let* ((arg-shapes (map cadr args))
                  (new-name-sets (map invent-names-for-parts formals arg-shapes))
                  (env (augment-env
                        (empty-env) formals new-name-sets arg-shapes))
                  (new-names (apply append new-name-sets)))
             `(define (,name ,@new-names)
                (argument-types ,@(map list new-names
                                       (append-map primitive-fringe arg-shapes))
                                ,(tidy-values `(values ,@(primitive-fringe return))))
                ,(sra-expression body env lookup-type))))
     (except-last-pair program))
    ;; TODO Reconstruct the shape that the entry point was supposed to
    ;; return?
    (sra-expression
     (car (last-pair program)) (empty-env) lookup-type)))

(define (check-expression-types expr env lookup-type)
  ;; A type environment maps every bound local name to its type.  The
  ;; lookup-type procedure returns the (function) type of any global
  ;; name passed to it.  CHECK-TYPE-CORRECT either returns the type of
  ;; the expression or signals an error if the expression is either
  ;; malformed or not type correct.
  (define (lookup-return-type thing)
    (return-type (lookup-type thing)))
  (define (lookup-arg-types thing)
    (arg-types (lookup-type thing)))
  ;; For this purpose, a VALUES is the same as any other construction,
  ;; but in other contexts they may need to be distinguished.
  (define (construction? expr)
    (and (pair? expr)
         (memq (car expr) '(cons vector values))))
  (define (loop expr env)
    (cond ((symbol? expr) (lookup expr env))
          ((number? expr) 'real)
          ((null? expr)   '())
          ((if-form? expr)
           (if (not (= 4 (length expr)))
               (error "Malformed IF" expr))
           (let ((pred-type (loop (cadr exp) env))
                 (cons-type (loop (caddr exp) env))
                 (alt-type (loop (cadddr exp) env)))
             (if (not (eq? 'bool pred-type))
                 (error "IF predicate not of boolean type" expr))
             (if (not (equal? cons-type alt-type))
                 ;; Note: this place will need to change to support union types
                 (error "Different IF branches return different types" expr))
             cons-type))
          ((let-form? expr)
           (if (not (= 3 (length expr)))
               (error "Malformed LET (excess body forms?)" expr))
           (let ((bindings (cadr expr))
                 (body (caddr expr)))
             (if (not (list? bindings))
                 (error "Malformed LET (non-list bindings)" expr))
             (let ((binding-types
                    (map (lambda (exp) (loop exp env)) (map cadr bindings))))
               (for-each
                (lambda (binding-type index)
                  (if (values-form? binding-type)
                      (error "LET binds a VALUES shape"
                             expr binding-type index)))
                binding-types
                (iota (length binding-types)))
               (loop body (augment-env env (map car bindings) binding-types)))))
          ((let-values-form? expr)
           (if (not (= 3 (length expr)))
               (error "Malformed LET-VALUES (excess body forms?)" expr))
           (let ((bindings (cadr expr))
                 (body (caddr expr)))
             (if (not (list? bindings))
                 (error "Malformed LET-VALUES (non-list bindings)" expr))
             (if (not (= 1 (length bindings)))
                 (error "Malformed LET-VALUES (multiple binding expressions)" expr))
             (let ((binding-type (loop (cadar bindings) env)))
               (if (not (values-form? binding-type))
                   (error "LET-VALUES binds a non-VALUES shape" expr binding-type))
               (loop body (augment-env env (caar bindings) (cdr binding-type))))))
          ((accessor? expr)
           (let ((accessee-type (loop (cadr expr) env)))
             (if (and (cons-ref? expr) (not (eq? 'cons (car accessee-type))))
                 (if (eq? 'car (car expr))
                     (error "Taking the CAR of a non-CONS" accessee-type)
                     (error "Taking the CDR of a non-CONS" accessee-type)))
             (if (vector-ref? expr)
                 (begin
                   (if (not (eq? 'vector (car accessee-type)))
                       (error "Trying to VECTOR-REF a non-VECTOR" accessee-type))
                   (if (not (< (caddr expr) (length (cdr accessee-type))))
                       (error "Index out of bounds" (caddr expr) accessee-type))))
             (select-from-shape-by-access accessee-type expr)))
          ((construction? expr)
           (let ((element-types (map (lambda (exp) (loop exp env))) (cdr expr)))
             (for-each
              (lambda (element-type index)
                (if (values-form? element-type)
                    (error "Trying to put a VALUES shape into a data structure"
                           expr element-type index)))
              element-types
              (iota (length element-types)))
             (construct-shape element-types expr)))
          (else ;; general application
           (let ((expected-types (lookup-arg-types (car expr)))
                 (argument-types (map (lambda (exp) (loop exp env))) (cdr expr)))
             (if (not (= (length expected-types) (length argument-types)))
                 (error "Trying to call function with wrong number of arguments" expr))
             (for-each
              (lambda (expected given index)
                (if (not (equal? expected given))
                    (error "Mismatched argument at function call"
                           expr index expected given)))
              expected-types
              argument-types
              (iota (length argument-types)))
             (lookup-return-type (car expr))))))
  (loop expr env))
