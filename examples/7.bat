(defrule init
	=>
	(assert
		(receive-queue (mq-open /original (create$ O_CREAT O_RDWR) 0600) 0)
		(send-queue (mq-open /modified (create$ O_CREAT O_RDWR) 0600) 0)))

(defrule upcase-color
	?r <- (receive-queue ?receive-queue ?i)
	?s <- (send-queue ?send-queue ?i)
	=>
	(retract ?r ?s)
	(mq-send ?send-queue 
		(str-cat 7: (upcase (mq-receive ?receive-queue))))
	(assert
		(receive-queue ?receive-queue (+ 1 ?i))
		(send-queue ?send-queue (+ 1 ?i))))

(run)
