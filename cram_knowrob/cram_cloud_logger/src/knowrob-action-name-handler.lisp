(in-package :ccl)

(defun get-knowrob-action-name-uri (cram-action-name designator)
  (concatenate 'string "knowrob:" (convert-to-prolog-str (get-knowrob-action-name cram-action-name designator))))

(defun get-knowrob-action-name (cram-action-name designator)
  (let ((knowrob-action-name cram-action-name))
    (cond ((string-equal cram-action-name "reaching")
           (setf knowrob-action-name "Reaching"))
          ((string-equal cram-action-name "retracting")
           (setf knowrob-action-name "Retracting"))
          ((string-equal cram-action-name "lifting")
           (setf knowrob-action-name "LiftingAnArm"))
          ((string-equal cram-action-name "putting")
           (setf knowrob-action-name "LoweringAnArm"))
          ((string-equal cram-action-name "setting-gripper")
           (setf knowrob-action-name "SettingAGripper"))
          ((string-equal cram-action-name "opening")
           (setf knowrob-action-name "OpeningAGripper"))
          ((string-equal cram-action-name "closing")
           (setf knowrob-action-name "ClosingAGripper"))
          ((string-equal cram-action-name "detecting")
           (setf knowrob-action-name "VisualPerception"))
          ((string-equal cram-action-name "placing")
           (setf knowrob-action-name "ReleasingGraspOfSomething"))
          ((string-equal cram-action-name "picking-up")
           (setf knowrob-action-name "AcquireGraspOfSomething"))
          ((string-equal cram-action-name "releasing")
           (setf knowrob-action-name "OpeningAGripper"))
          ((string-equal cram-action-name "gripping")
           (setf knowrob-action-name "ClosingAGripper"))
          ((string-equal cram-action-name "looking")
           (setf knowrob-action-name "LookingAtLocation"))
          ((string-equal cram-action-name "going")
           (setf knowrob-action-name "BaseMovement"))
          ((string-equal cram-action-name "navigating")
           (setf knowrob-action-name "MovingToLocation"))
          ((string-equal cram-action-name "searching")
           (setf knowrob-action-name "LookingForSomething"))
          ((string-equal cram-action-name "fetching")
           (setf knowrob-action-name "PickingUpAnObject"))
          ((string-equal cram-action-name "delivering")
           (setf knowrob-action-name "PuttingDownAnObject"))
          ((string-equal cram-action-name "Transporting")
           (setf knowrob-action-name "FetchAndDeliver"))
          ((string-equal cram-action-name "Turning-Towards")
           (setf knowrob-action-name "LookingForSomething"))
          ((string-equal cram-action-name "SEALING")
           (setf knowrob-action-name "MovingToOperate"))
          ((string-equal cram-action-name "PUSHING")
           (setf knowrob-action-name "Pushing"))
          ((string-equal cram-action-name "PULLING")
           (setf knowrob-action-name "Pulling"))
          ((string-equal cram-action-name "ACCESSING")
           (setf knowrob-action-name "MovingToOperate")))
    ;;(if (string-equal knowrob-action-name "OpeningAGripper")
    ;;    (if (desig:desig-prop-value designator :gripper)
    ;;        (setf knowrob-action-name "OpeningAGripper")
    ;;        (setf knowrob-action-name "OpeningADrawer")))
    ;;(if (string-equal knowrob-action-name "ClosingAGripper")
    ;;    (if (desig:desig-prop-value designator :gripper)
    ;;        (setf knowrob-action-name "ClosingAGripper")
    ;;        (setf knowrob-action-name "ClosingADrawer")))
    knowrob-action-name))
