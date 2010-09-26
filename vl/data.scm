(define (variable? thing)
  (or (symbol? thing)
      (boolean? thing)
      (number? thing)))

(define (constant? thing)
  (and (variable? thing)
       (not (symbol? thing))))

(define-structure (closure (safe-accessors #t))
  formal
  body
  env)

(define-structure (primitive (safe-accessors #t))
  name
  arity
  implementation
  abstract-implementation)

(define (vl-value->scheme-value thing)
  thing)

(define (primitive-unary? primitive)
  (= 1 (primitive-arity primitive)))