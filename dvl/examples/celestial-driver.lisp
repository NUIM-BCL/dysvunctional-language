(defmacro delay (exp)
  `(lambda () ,exp))

(defun force (thunk)
  (funcall thunk))

(defun constant-arg-for-dvl-stream (argument dvl-stream)
  (labels ((do-it (dvl-stream)
             (cons (car dvl-stream)
                   (delay (do-it (funcall (cdr dvl-stream) argument))))))
    (do-it dvl-stream)))

(defun stream-for-each (f stream)
  (cons (funcall f (car stream))
        (delay (stream-for-each f (force (cdr stream))))))

(defun stream-take (count stream)
  (if (= count 0)
      stream
      (stream-take (- count 1) (force (cdr stream)))))

(defun drive (count step dt)
  (stream-take count
   (constant-arg-for-dvl-stream (coerce dt 'double-float)
    (funcall (__main__) (coerce step 'double-float)))))