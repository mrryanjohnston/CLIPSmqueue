(defrule open
	=>
	(assert (queue (mq-open /foo (create$ O_CREAT O_RDWR) 0600) 0)))

(defrule check-queue
	(queue ?queue&~FALSE ?)
	(not (has-message ?))
	=>
	(assert (has-message (= 1 (nth$ 4 (mq-getattr ?queue))))))

(defrule read-message
	(queue ?queue ?total&:(> 5 ?total))
	(has-message TRUE)
	=>
	(assert (message (mq-receive ?queue))))

(defrule counter
	?q <- (queue ?queue ?total)
	?h <- (has-message TRUE)
	?m <- (message ?msg)
	=>
	(retract ?q ?h ?m)
	(println "Msg: " ?msg)
	(assert (queue ?queue (string-to-field ?msg))))

(defrule send
	(queue ?queue ?total)
	?h <- (has-message FALSE)
	=>
	(retract ?h)
	(mq-send ?queue (str-cat (+ 1 ?total))))

(defrule end
	(queue ?queue 5)
	=>
	(mq-close ?queue)
	(mq-unlink /foo)
	(println "Done!"))

(run)
