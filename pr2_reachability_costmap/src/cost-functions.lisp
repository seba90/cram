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

(in-package :pr2-reachability-costmap)

(defparameter *package-name* "pr2_reachability_costmap")
(defparameter *reachability-map-files*
  '((:left . "resource/pr2-reachability-map-left-5cm.map")
    (:right . "resource/pr2-reachability-map-right-5cm.map")))
(defparameter *ik-reference-frame* "torso_lift_link")

(defvar *reachability-maps* nil)

(defun get-reachability-map (side)
  (let ((map (cdr (assoc side *reachability-maps*))))
    (or map
        (let ((reachability-map
                (make-instance 'reachability-map
                  :filename (concatenate
                             'string
                             (namestring (ros-load:ros-package-path
                                          *package-name*))
                             (cdr (assoc side *reachability-map-files*))))))
          (push (cons side reachability-map) *reachability-maps*)
          reachability-map))))

(defun matrix-cost-function (origin-x origin-y resolution matrix)
  (declare (type number origin-x origin-y resolution)
           (type cma:double-matrix matrix))
  (flet ((generator (costmap-metadata output-matrix)
           (declare (type cma:double-matrix output-matrix))
           (let ((start-x (max origin-x (origin-x costmap-metadata)))
                 (start-y (max origin-y (origin-y costmap-metadata)))
                 (end-x  (min (array-index->map-coordinate
                               (1- (cma:width matrix)) resolution origin-x)
                              (+ (width costmap-metadata) (origin-x costmap-metadata))))
                 (end-y (min (array-index->map-coordinate
                               (1- (cma:width matrix)) resolution origin-x)
                             (+ (height costmap-metadata) (origin-y costmap-metadata)))))
             (loop for y-source-index from (map-coordinate->array-index start-y resolution origin-y)
                     below (map-coordinate->array-index end-y resolution origin-y)
                       by (/ (resolution costmap-metadata) resolution)
                   for y-destination-index from (map-coordinate->array-index
                                                 start-y (resolution costmap-metadata)
                                                 (origin-y costmap-metadata))
                     below (map-coordinate->array-index
                            end-y (resolution costmap-metadata)
                            (origin-y costmap-metadata))
                       by (/ resolution (resolution costmap-metadata))
                   do (loop for x-source-index from (map-coordinate->array-index
                                                     start-x resolution origin-x)
                              below (map-coordinate->array-index end-x resolution origin-x)
                                by (/ (resolution costmap-metadata) resolution)
                            for x-destination-index from (map-coordinate->array-index
                                                          start-x (resolution costmap-metadata)
                                                          (origin-x costmap-metadata))
                              below (map-coordinate->array-index
                                     end-x (resolution costmap-metadata)
                                     (origin-x costmap-metadata))
                                by (/ resolution (resolution costmap-metadata))
                            do (setf
                                (aref output-matrix
                                      (truncate y-destination-index)
                                      (truncate x-destination-index))
                                (aref matrix
                                      (truncate y-source-index) (truncate x-source-index))))
                   finally (return output-matrix)))))
    #'generator))

(defun make-inverse-reachability-matrix
    (reachability-map-matrix z-index orientation-indices)
  (declare (type simple-array reachability-map-matrix)
           (type fixnum z-index)
           (type list orientation-indices))
  (let ((result (cma:make-double-matrix
                 (array-dimension reachability-map-matrix 2)
                 (array-dimension reachability-map-matrix 1))))
    (dotimes (y (array-dimension reachability-map-matrix 1))
      (dotimes (x (array-dimension reachability-map-matrix 2))
        (dolist (orientation-index orientation-indices)
          (incf (aref result y x) (aref reachability-map-matrix
                                        z-index y x orientation-index)))))
    (cma:m./ result (float (list-length orientation-indices) 0.0d0))))

(defun make-inverse-reachability-costmap (sides point &optional orientations)
  (flet ((get-orientation-indices (reachability-map orientations)
           (loop for orientation in orientations
                 collecting (remove
                             nil (position
                                  orientation (orientations reachability-map)
                                  :test (lambda (orientation-1 orientation-2)
                                          (< (cl-transforms:angle-between-quaternions
                                              orientation-1 orientation-2)
                                             1e-6)))))))
    (let* ((point-in-map (tf:transform-point
                         cram-roslisp-common:*tf*
                         :point point :target-frame designators-ros:*fixed-frame*))
           (point-in-ik-frame (tf:transform-point
                              cram-roslisp-common:*tf*
                              :point point :target-frame *ik-reference-frame*))
           (functions (mapcar
                       (lambda (side)
                         (let ((reachability-map (get-reachability-map side)))
                           ;; TODO(moesenle) don't ignore orientation
                           (matrix-cost-function
                            (+ (cl-transforms:x (origin reachability-map))
                               (cl-transforms:x point-in-map))
                            (+ (cl-transforms:y (origin reachability-map))
                               (cl-transforms:y point-in-map))
                            ;; TODO(moesenle) verify resolution
                            (cl-transforms:x (resolution reachability-map))
                            (make-inverse-reachability-matrix
                             (reachability-map reachability-map)
                             (map-coordinate->array-index
                              (cl-transforms:z point-in-ik-frame)
                              (cl-transforms:z (resolution reachability-map))
                              (cl-transforms:z (origin reachability-map)))
                             (get-orientation-indices
                              reachability-map orientations)))))
                       sides)))
      (make-instance 'map-costmap-generator
        :generator-function (lambda (costmap-metadata matrix)
                              (reduce (lambda (previous-matrix function)
                                        (cma:m+
                                         previous-matrix
                                         (funcall
                                          function costmap-metadata
                                          (cma:make-double-matrix
                                           (cma:width previous-matrix)
                                           (cma:height previous-matrix)))))
                                      (cdr functions)
                                      :initial-value (funcall
                                                      (car functions)
                                                      costmap-metadata matrix)))
        :name :inverse-reachability-costmap))))
