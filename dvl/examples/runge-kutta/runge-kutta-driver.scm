;;; ----------------------------------------------------------------------
;;; Copyright 2010-2011 National University of Ireland.
;;; ----------------------------------------------------------------------
;;; This file is part of DysVunctional Language.
;;; 
;;; DysVunctional Language is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU Affero General Public License as
;;; published by the Free Software Foundation, either version 3 of the
;;;  License, or (at your option) any later version.
;;; 
;;; DysVunctional Language is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;; 
;;; You should have received a copy of the GNU Affero General Public License
;;; along with DysVunctional Language.  If not, see <http://www.gnu.org/licenses/>.
;;; ----------------------------------------------------------------------

;;; Load this after compiling runge-kutta.dvl with
;;; (fol->floating-mit-scheme (compile-to-fol (dvl-source "examples/runge-kutta/integrations.dvl") visibly))
;;; and feel free to draw some pictures.

(define integrations (run-mit-scheme))

(define exp-euler   (car integrations))
(define exp-rk4    (cadr integrations))
(define sin-euler (caddr integrations))
(define sin-rk4  (cadddr integrations))

(define (integrate integration time-step total-time)
  (let loop ((result '())
             (integration integration))
    (let* ((state (car integration))
           (current-time (car state))
           (func (cdr integration)))
      (if (> current-time total-time)
          (reverse result)
          (loop (cons state result)
                (func time-step))))))

(define (plot xxx command time-series)
  (gnuplot-alist
   (map (lambda (datum)
          (let ((time (car datum))
                (estimate (cadr datum)))
            (cons time (xxx time estimate))))
        time-series)
   `(commanding ,command)))

(define (estimate time estimate) estimate)

(define ((relative-error truth) time estimate)
  (if (>= (abs (truth time)) 1)
      (/ (- (truth time) estimate) (truth time))
      (- (truth time) estimate)))

(plot estimate "with points, exp(x)"
 (integrate exp-euler 0.25 10))

(plot estimate "with points, exp(x)"
 (integrate exp-rk4 1.0 10)) ; RK4 calls the function 4 times per step

(plot (relative-error exp) "with points"
 (integrate exp-rk4 1.0 10))

(plot estimate "with points, sin(x)"
 (integrate sin-euler 0.25 10))

(plot estimate "with points, sin(x)"
 (integrate sin-rk4 1.0 10)) ; RK4 calls the function 4 times per step

(plot (relative-error sin) "with points"
 (integrate sin-rk4 1.0 10))