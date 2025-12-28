(deffunction do ()
	(bind ?mqd (mq-open /foo (create$ O_CREAT O_RDWR) 0600))
	(println "Created /foo mqueue...")
	(loop-for-count (?cnt 1 1000000) do
		(mq-send ?mqd (str-cat ?cnt)))
	(println "Sent messages to /foo mqueue...")
	(mq-close ?mqd)
	(println "Closed file descriptor for mqueue /foo...")
	(println "Done! Now run ./vendor/clips/clips -f2 example/5.bat to receive your messages!"))
(do)
(exit)

