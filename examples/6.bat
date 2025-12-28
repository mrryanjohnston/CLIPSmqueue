(deftemplate color (slot name) (slot next))
(defrule init
	=>
	(bind ?first (assert (color (name violet))))
	(bind ?second (assert
		(color (name red) (next (assert
		(color (name orange) (next (assert
		(color (name yellow) (next (assert
		(color (name green) (next (assert
		(color (name blue) (next (assert
		(color (name indigo) (next ?first)))))))))))))))))))
	(modify ?first (next ?second))
	(assert
		(next-color ?first)
		(send-queue (mq-open /original (create$ O_CREAT O_RDWR O_NONBLOCK) 0600) 0)
		(receive-queue (mq-open /modified (create$ O_CREAT O_RDWR) 0600) 0)))

(defrule check-receive-queue
	?r <- (receive-queue ?queue&~FALSE ?)
	=>
	(assert (mq-attr ?r (mq-getattr ?queue))))

(defrule check-send-queue
	?s <- (send-queue ?queue&~FALSE ?)
	=>
	(assert (mq-attr ?s (mq-getattr ?queue))))

(defrule receive-from-receive-queue-when-send-full
	?r <- (receive-queue ?queue ?i)
	?m <- (mq-attr ?r ? ? ? ?)

	?s <-  (send-queue ?send-queue ?si)
               (mq-attr ?s ? ?msgs ? ?msgs)
	=>
	(assert (received (mq-receive ?queue (clock-gettime (create$ 10 0))))))

(defrule receive-timed-out
	(received FALSE)
	(receive-queue ?receive-queue ?)
	(send-queue ?send-queue ?)
	=>
	(println "Received timed out. bye bye!")
	(mq-close ?receive-queue)
	(mq-close ?send-queue)
	(mq-unlink /original)
	(mq-unlink /modified))

(defrule print-from-receive-queue
	?r <- (receive-queue ?queue ?i)
	?m <- (mq-attr ?r ? ? ? ?)

	?s <-  (send-queue ?send-queue ?si)
	?sm <- (mq-attr ?s ? ?msgs ? ?msgs)
	?received <- (received ?color&~FALSE)
	=>
	(retract ?r ?m ?received ?s ?sm)
	(println "color from receive queue: " ?color)
	(assert
		(receive-queue ?queue (+ 1 ?i))
		(send-queue ?send-queue (+ 1 ?si))))

(defrule push-next-color-onto-send-queue
	?s <- (send-queue ?queue ?counter)
	?m <- (mq-attr ?s ? ?maxmsgs ? ?curmsgs&:(> ?maxmsgs ?curmsgs))

	?c <- (color (name ?name) (next ?next))
	?n <- (next-color ?c)
	=>
	(retract ?s ?n ?m)
	(mq-send ?queue ?name)
	(assert
		(next-color ?next)
		(send-queue ?queue (+ 1 ?counter))))

(run)
