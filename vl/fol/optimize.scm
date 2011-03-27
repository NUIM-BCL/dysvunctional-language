(declare (usual-integrations))
;;;; Optimization toplevel

;;; The FOL optimizer consists of several stages:
;;; - STRUCTURE-DEFINITIONS->VECTORS
;;;   Replace DEFINE-STRUCTURE with explicit vectors.
;;; - INLINE
;;;   Inline non-recursive function definitions.
;;; - ALPHA-RENAME
;;;   Change local variable names to avoid shadowing anything.
;;; - APPROXIMATE-ANF
;;;   Convert the program to A-normal form to prepare for SRA.
;;; - SCALAR-REPLACE-AGGREGATES
;;;   Replace aggregates with scalars.  This relies on argument-type
;;;   annotations and requires approximate A-normal form.
;;; - INTRAPROCEDURAL-DE-ALIAS
;;;   Eliminate redundant variables that are just aliases of other
;;;   variables or constants.
;;; - INTRAPROCEDURAL-DEAD-VARIABLE-ELIMINATION
;;;   Eliminate dead code.
;;; - TIDY
;;;   Clean up and optimize locally by term-rewriting.  This includes
;;;   a simple-minded reverse-anf which inlines bindings of variables
;;;   that are only used once, to make the output easier to read.

(define (fol-optimize program)
  ((lambda (x) x) ; This makes the last stage show up in the stack sampler
   (tidy
    (eliminate-intraprocedural-dead-variables
     (intraprocedural-de-alias
      (scalar-replace-aggregates
       (inline                          ; includes ALPHA-RENAME
        program)))))))

;;; The stages have the following structure and interrelationships:
;;;
;;; STRUCTURE-DEFINITIONS->VECTORS has to be done first, because none
;;; of the other stages can handle DEFINE-STRUCTURE forms, but it need
;;; only be done once because no stage introduces DEFINE-STRUCTURE
;;; forms.
;;;
;;; After that, almost all other stages (notably except INLINE) depend
;;; on but also preserve uniqueness of variable names, so ALPHA-RENAME
;;; should be done next.  The definition of FOL-OPTIMIZE above bums
;;; this by noting that INLINE is called first anyway and relying on
;;; the ALPHA-RENAME inside it.
;;;
;;; Scalar replacement of aggregates pre-converts its input into
;;; approximate A-normal form, and does not attempt to undo this
;;; conversion.  This means other stages may have interesting
;;; commutators with SCALAR-REPLACE-AGGREGATES through their effect on
;;; ANF.
;;;
;;; Inlining is not idempotent in theory (see discussion in
;;; feedback-vertex-set.scm) but is idempotent on the extant examples.
;;;
;;; Inlining implies ANF-conversion of the call sites of the
;;; procedures that were inlined.  Otherwise it commutes with SRA (up
;;; to removal of aliases).  I think inlining makes SRA go faster
;;; because it reduces the number of procedure boundaries.
;;;
;;; Inlining exposes aliases to de-aliasing by collapsing procedure
;;; boundaries.
;;;
;;; Inlining exposes dead variables to elimination by collapsing
;;; procedure boundaries.
;;;
;;; Inlining exposes opprotunities for tidying by collapsing procedure
;;; boundaries.
;;;
;;; SRA commutes with inlining up to removal of aliases.
;;;
;;; SRA is idempotent except in the case of structured returns (or in
;;; the non-union-free case for feedback-vertex-set reasons).
;;;
;;; SRA exposes structure-slot aliases to variable de-aliasing.
;;;
;;; SRA exposes dead structure slots to elimination.
;;;
;;; SRA exposes tidying opportunities across containment in
;;; structures.
;;;
;;; De-aliasing does not create new inlining opportunities.
;;;
;;; De-aliasing does not create SRA opportunities.
;;;
;;; De-aliasing is idempotent.
;;;
;;; De-aliasing leaves some aliases around to be cleaned up by dead
;;; variable elimination, in the case where some names bound by a
;;; multiple value binding are aliases but others are not.
;;;
;;; De-aliasing exposes tidying opportunities, for example by constant
;;; propagation.
;;;
;;; Dead variable elimination may delete edges in the call graph (if
;;; the result of a called procedure turned out not to be used); and
;;; may thus open inlining opportunities.
;;;
;;; Dead variable elimination does not create SRA opportunities
;;; (though it could in the non-union-free case if I eliminated dead
;;; structure slots and were willing to change the type graph
;;; accordingly).
;;;
;;; Dead variable elimination does not expose aliases.
;;;
;;; Dead variable elimination is idempotent.
;;;
;;; Dead variable elimination exposes tidying opportunities, for
;;; example by collapsing intervening LETs or by making bindings
;;; singletons.
;;;
;;; Tidying may delete edges in the call graph (by, e.g., eliminating
;;; (* 0 (some-proc foo bar baz))).
;;;
;;; Tidying does not create SRA opportunities (though it could in the
;;; non-union-free case).  It does, however, do some reverse
;;; ANF-conversion, in the form of inlining variables that are only
;;; used once.
;;;
;;; Tidying may expose aliases by removing intervening arithmetic
;;; operations.
;;;
;;; Tidying may expose dead variables by eliminating (* 0 foo).
;;;
;;; Tidying is idempotent (because it is run to convergence).

;;; Don't worry about the rule-based term-rewriting system that powers
;;; this.  That is its own pile of stuff, good for a few lectures of
;;; Sussman's MIT class Adventures in Advanced Symbolic Programming.
;;; It works, and it's very good for peephole manipulations of
;;; structured expressions (like the output of the VL code generator).
;;; If you really want to see it, though, it's included in
;;; support/rule-system.

;;; Rules for the term-rewriting system consist of a pattern to try to
;;; match and an expression to evaluate to compute a replacement for
;;; that match should a match be found.  Patterns match themselves;
;;; the construct (? name) introduces a pattern variable named name;
;;; the construct (? name ,predicate) is a restricted pattern variable
;;; which only matches things the predicate accepts; the construct (??
;;; name) introduces a sublist pattern variable.  The pattern matcher
;;; will search through possible lengths of sublists to find a match.
;;; Repeated pattern variables must match equal structures in all the
;;; corresponding places.

;;; A rule by itself is a one-argument procedure that tries to match
;;; its pattern.  If the match succeeds, the rule will evaluate the
;;; the replacement expression in an environment where the pattern
;;; variables are bound to the things they matched and return the
;;; result.  If the replacement expression returns #f, that tells the
;;; matcher to backtrack and look for another match.  If the match
;;; fails, the rule will return #f.

;;; A rule simplifier has a set of rules, and applies them to every
;;; subexpression of the input expression repeatedly until the result
;;; settles down.

;;;; Term-rewriting tidier

(define empty-let-rule (rule `(let () (? body)) body))

;; This is safe assuming the program has unique bound names; if not,
;; can break because of
#;
 (let ((x 3))
   (let ((y (let ((x 4)) x)))
     x))
;; Unfortunately, mere lack of shadowing is not enough, as this can
;; introduce shadowing because of
#;
 (let ((x (let ((y 3)) y)))
   (let ((y 4))
     y))
(define let-let-lifting-rule
  (rule `(let ((?? bindings1)
               ((? name ,symbol?) (let (? in-bindings) (? exp)))
               (?? bindings2))
           (?? body))
        `(let ,in-bindings
           (let (,@bindings1
                 (,name ,exp)
                 ,@bindings2)
             ,@body))))

;; This is safe assuming the program has been alpha renamed
(define values-let-lifting-rule
  (rule `(let-values (((? names) (let (? in-bindings) (? exp))))
           (?? body))
        `(let ,in-bindings
           (let-values ((,names ,exp))
             ,@body))))

;; This is safe assuming the program has been alpha renamed
(define singleton-inlining-rule
  (rule `(let ((?? bindings1)
               ((? name ,symbol?) (? exp))
               (?? bindings2))
           (?? body))
        (let ((occurrence-count (count-free-occurrences name body)))
          (and (= 1 occurrence-count)
               `(let (,@bindings1
                      ,@bindings2)
                  ,@(replace-free-occurrences name exp body))))))

(define tidy
  (rule-simplifier
   (list
    (rule `(begin (? body)) body)
    (rule `(* 0 (? thing)) 0)
    (rule `(* (? thing) 0) 0)
    (rule `(+ 0 (? thing)) thing)
    (rule `(+ (? thing) 0) thing)
    (rule `(* 1 (? thing)) thing)
    (rule `(* (? thing) 1) thing)

    (rule `(if (? predicate) (? exp) (? exp))
          exp)

    (rule `(let-values (((? names) (values (?? stuff))))
             (?? body))
          `(let ,(map list names stuff)
             ,@body))

    empty-let-rule

    values-let-lifting-rule
    singleton-inlining-rule)))


