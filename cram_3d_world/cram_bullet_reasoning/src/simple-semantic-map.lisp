;;; Copyright (c) 2012, Lorenz Moesenlechner <moesenle@in.tum.de>
;;; All rights reserved.
;;; 
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are met:
;;; 
;;;     * Redistributions of source code must retain the above copyright
;;;       notice, this list of conditions and the following disclaimer.
;;;     * Redistributions in binary form must reproduce the above copyright
;;;       notice, this list of conditions and the following disclaimer in the
;;;       documentation and/or other materials provided with the distribution.
;;;     * Neither the name of the Intelligent Autonomous Systems Group/
;;;       Technische Universitaet Muenchen nor the names of its contributors 
;;;       may be used to endorse or promote products derived from this software 
;;;       without specific prior written permission.
;;; 
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;;; POSSIBILITY OF SUCH DAMAGE.

(in-package :btr)

(defclass simple-semantic-map-object (semantic-map-object) ())

(defmethod initialize-instance :after ((semantic-map-object simple-semantic-map-object)
                                       &key (collision-group :default-filter)
                                         (collision-mask :all-filter)
                                         (pose (cl-transforms:make-identity-pose)))
  (with-slots (pose-reference-body semantic-map) semantic-map-object
    (let ((bodies (loop for part in (sem-map-utils:semantic-map-parts
                                     semantic-map :recursive t)
                        for body = (semantic-map-part-rigid-body
                                    part
                                    :pose pose
                                    :collision-group collision-group
                                    :collision-mask collision-mask)
                        when body collect body)))
      (initialize-rigid-bodies semantic-map-object bodies)
      (setf pose-reference-body (car bodies)))))

(defmethod copy-object ((obj simple-semantic-map-object) (world bt-reasoning-world))
  (with-slots (semantic-map) obj
    (change-class
     (call-next-method) 'simple-semantic-map-object
     :semantic-map (sem-map-utils:copy-semantic-map-object semantic-map))))

(defgeneric semantic-map-part-rigid-body (part &key pose collision-group collision-mask)
  (:documentation "Returns a rigid body for the semantic map part `part'.")
  (:method ((part sem-map-utils:semantic-map-geom) &key pose collision-group collision-mask)
    (make-instance 'rigid-body
      :name (intern (sem-map-utils:name part))
      :group collision-group
      :mask collision-mask
      :pose (cl-transforms:transform-pose
             (cl-transforms:pose->transform pose)
             (sem-map-utils:pose part))
      :collision-shape (let* ((mesh-uri (semantic-map-utils::get-mesh-path (semantic-map-utils:owl-name part)))
                             (mesh-path (physics-utils:parse-uri mesh-uri)))
                             (let ((mesh-model
                                     (physics-utils:scale-3d-model
                                      (if mesh-path
                                          (with-file-cache model mesh-path (physics-utils:load-3d-model mesh-path)
                                            model)
                                          (roslisp:ros-warn (btr) "No mesh-path was defined."))
                                      1.0))) ;scale value
      
                         (if mesh-path
                             (make-instance 'convex-hull-mesh-shape
                               :points (physics-utils:3d-model-vertices mesh-model)
                               :faces (physics-utils:3d-model-faces mesh-model)
                               :color '(0.5 0.5 0.5 1.0))
                             
                             (make-instance 'box-shape
                               :half-extents (cl-transforms:v*
                                              (sem-map-utils:dimensions part)
                                              0.5)))))))
  
  (:method ((part t) &key pose collision-group collision-mask)
    (declare (ignore pose collision-group collision-mask))
    (warn 'simple-warning
          :format-control "Unable to generate a rigid body for semantic map part of type `~a'."
          :format-arguments (list (type-of part)))))
