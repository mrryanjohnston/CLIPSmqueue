(deffunction str-reverse (?str)
	(bind ?out "")
	(loop-for-count (?cnt 0 (str-length ?str)) do
		(bind ?index (- (str-length ?str) ?cnt))
		(bind ?out (str-cat ?out (sub-string ?index ?index ?str))))
	(return ?out))

(defrule init
	=>
	(assert
		(receive-queue (mq-open /original (create$ O_CREAT O_RDWR) 0600) 0)
		(send-queue (mq-open /modified (create$ O_CREAT O_RDWR) 0600) 0)))

(defrule reverse-color
	?r <- (receive-queue ?receive-queue ?i)
	?s <- (send-queue ?send-queue ?i)
	=>
	(retract ?r ?s)
	(mq-send ?send-queue 
		(str-cat 8: (str-reverse (mq-receive ?receive-queue))))
	(assert
		(receive-queue ?receive-queue (+ 1 ?i))
		(send-queue ?send-queue (+ 1 ?i))))

(run)
