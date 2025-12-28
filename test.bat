; ----------------------------------------------------------------------
; CLIPSmqueue test suite
; ----------------------------------------------------------------------

(defglobal
  ?*tests-ran* = 0
  ?*tests-failed* = 0)

(deffunction expect (?title ?expected ?actual)
  (bind ?*tests-ran* (+ ?*tests-ran* 1))
  (if (eq ?expected ?actual)
   then
    (printout t ".")
   else
    (bind ?*tests-failed* (+ ?*tests-failed* 1))
    (printout t crlf "[FAILED TEST] " ?title
                " expected=" ?expected
                " actual=" ?actual crlf)))

(deffunction refute (?title ?expected ?actual)
  (bind ?*tests-ran* (+ ?*tests-ran* 1))
  (if (not (eq ?expected ?actual))
   then
    (printout t ".")
   else
    (bind ?*tests-failed* (+ ?*tests-failed* 1))
    (printout t crlf "[FAILED TEST] " ?title
                " expected-not=" ?expected
                " actual=" ?actual crlf)))

(deffunction mq-test-summary ()
  (printout t crlf "Tests run: " ?*tests-ran* "  Failures: " ?*tests-failed* crlf))

; ----------------------------------------------------------------------
; Structures for mq_attr via facts and instances
; ----------------------------------------------------------------------

(deftemplate mq-attr
  (slot flags)
  (slot maxmsg)
  (slot msgsize)
  (slot curmsgs))

(defclass MQ-ATTR (is-a USER)
  (slot flags (type INTEGER))
  (slot maxmsg (type INTEGER))
  (slot msgsize (type INTEGER))
  (slot curmsgs (type INTEGER)))

(deftemplate custom-mq-attr
  (slot flags)
  (slot maxmsg)
  (slot msgsize)
  (slot curmsgs))

(defclass CUSTOM-MQ-ATTR (is-a USER)
  (slot flags (type INTEGER))
  (slot maxmsg (type INTEGER))
  (slot msgsize (type INTEGER))
  (slot curmsgs (type INTEGER)))

(deftemplate custom-mq-attr-flags
  (slot flags))

(deftemplate custom-mq-attr-maxmsg
  (slot maxmsg))

(deftemplate custom-mq-attr-msgsize
  (slot msgsize))

(deftemplate custom-mq-attr-curmsgs
  (slot curmsgs))

(defclass CUSTOM-MQ-ATTR-FLAGS (is-a USER)
  (slot flags (type INTEGER)))

(defclass CUSTOM-MQ-ATTR-MAXMSG (is-a USER)
  (slot maxmsg (type INTEGER)))

(defclass CUSTOM-MQ-ATTR-MSGSIZE (is-a USER)
  (slot msgsize (type INTEGER)))

(defclass CUSTOM-MQ-ATTR-CURMSGS (is-a USER)
  (slot curmsgs (type INTEGER)))

; ----------------------------------------------------------------------
; Structures for sigevent via facts and instances (mq-notify)
; ----------------------------------------------------------------------

(deftemplate mq-sigevent
  (slot notify)
  (slot signo)
  (slot value))

(defclass mq-sigevent-class (is-a USER)
  (slot notify (type INTEGER))
  (slot signo (type INTEGER))
  (slot value (type INTEGER)))

; ----------------------------------------------------------------------
; Structures for mq-send/mq-receive via facts and instances
; ----------------------------------------------------------------------

(deftemplate mq-message
  (slot data)
  (slot priority))

(defclass MQ-MESSAGE (is-a USER)
  (slot data (type LEXEME))
  (slot priority (type INTEGER)))

; ----------------------------------------------------------------------
; Structures for timespec via facts and instances (mq-timedreceive)
; ----------------------------------------------------------------------

(deftemplate mq-timespec
  (slot sec)
  (slot nsec))

(defclass mq-timespec-class (is-a USER)
  (slot sec (type INTEGER))
  (slot nsec (type INTEGER)))

; ----------------------------------------------------------------------
; Additional generic structures for negative tests
; ----------------------------------------------------------------------

(deftemplate other-template
  (slot foo))

(defclass OTHER-CLASS (is-a USER)
  (slot foo))

  ; ----------------------------------------------------------------------
; ErrnoFunction 100% LOC tests (drive errno via existing mqueue UDFs)
; Assumes:
;   (errno) -> FALSE when errno==0, else symbol like EINVAL, EBADF, ...
;   mq-* UDFs print errors and return FALSE on failure
; ----------------------------------------------------------------------

(deffunction run-errno-tests ()
  ; reset
  (expect "errno: baseline is FALSE" FALSE (errno))

  ; ---------- EBADF ----------
  (mq-close -1)
  (expect "errno: mq-close(-1) sets EBADF" EBADF (errno))

  (bind ?gi (mq-getattr -1 multifield))
  (expect "errno: mq-getattr(-1) sets EBADF" EBADF (errno))

  (bind ?si (mq-setattr -1 (create$ 0 1 16 0) multifield))
  (expect "errno: mq-setattr(-1) sets EBADF" EBADF (errno))

  (bind ?snd (mq-send -1 "x"))
  (expect "errno: mq-send(-1) sets EBADF" EBADF (errno))

  (bind ?rcv (mq-receive -1))
  (expect "errno: mq-receive(-1) sets EBADF" EBADF (errno))

  ; ---------- EINVAL (mq_unlink name) ----------
  (mq-unlink "")
  (expect "errno: mq-unlink(\"\") sets EINVAL or ENOENT"
          TRUE
          (or (eq (errno) EINVAL) (eq (errno) ENOENT)))

  ; ---------- ENOENT ----------
  (mq-unlink "/definitely-not-a-queue-errno-test-12345")
  (expect "errno: mq-unlink(nonexistent) sets ENOENT" ENOENT (errno))

  ; ---------- EEXIST ----------
  (bind ?name (format nil "/errno-eexist-%s" (gensym*)))
  (bind ?q1 (mq-open ?name (create$ O_CREAT O_EXCL O_RDWR O_NONBLOCK) 600 (create$ 0 1 16 0)))
  (expect "errno: created queue" TRUE (integerp ?q1))

  (bind ?q2 (mq-open ?name (create$ O_CREAT O_EXCL O_RDWR O_NONBLOCK) 600 (create$ 0 1 16 0)))
  (expect "errno: mq-open(O_CREAT|O_EXCL) second time sets EEXIST" EEXIST (errno))

  ; ---------- EMSGSIZE ----------
  ; msgsize=16; send 17 bytes (no NUL)
  (bind ?big "0123456789abcdefg")
  (mq-send ?q1 ?big)
  (expect "errno: mq-send oversize sets EMSGSIZE" EMSGSIZE (errno))

  ; ---------- EAGAIN ----------
  ; maxmsg=1, nonblocking. fill queue then send again => EAGAIN
  (mq-send ?q1 "a")
  (expect "errno: mq-send fill queue keeps errno FALSE" FALSE (errno))

  (mq-send ?q1 "b")
  (expect "errno: mq-send on full nonblocking queue sets EAGAIN" EAGAIN (errno))

  ; cleanup
  (mq-close ?q1)
  (mq-unlink ?name)

  ; ---------- ETIMEDOUT (must use a blocking queue: NO O_NONBLOCK) ----------
  (bind ?tname (format nil "/errno-timeout-%s" (gensym*)))
  (bind ?tq (mq-open ?tname (create$ O_CREAT O_EXCL O_RDWR) 600 (create$ 0 1 16 0)))
  (expect "errno: created blocking queue for timeout test" TRUE (integerp ?tq))
  
  ; absolute timeout in the past => timedreceive should fail immediately
  (mq-receive ?tq (create$ 0 0) string)
  (expect "errno: timedreceive on empty blocking queue w/ past deadline sets ETIMEDOUT (or EINVAL on some libs)"
        TRUE
        (or (eq (errno) ETIMEDOUT) (eq (errno) EINVAL)))

  (mq-close ?tq)
  (mq-unlink ?tname)
  
  ; ---------- FALSE path (force a guaranteed success after a failure) ----------
  ; make a failure first
  (mq-send -1 "x")
  (expect "errno: mq-send(-1) sets EBADF" EBADF (errno))

  ; now do a guaranteed-success syscall that sets errno=0 before calling (your mq-unlink does)
  (bind ?okname (format nil "/errno-ok-%s" (gensym*)))
  (bind ?okq (mq-open ?okname (create$ O_CREAT O_EXCL O_RDWR O_NONBLOCK) 600 (create$ 0 1 16 0)))
  (expect "errno: open okq returns integer" TRUE (integerp ?okq))
  
  (mq-close ?okq)   ; mq-close sets errno=0 before calling
  (expect "errno: after successful mq-close, errno is FALSE" FALSE (errno))
  
  (mq-unlink ?okname))

; ----------------------------------------------------------------------
; Test driver for mq-getattr
; ----------------------------------------------------------------------

(deffunction run-mq-getattr-tests ()
  (bind ?name (format nil "/mq-getattr-%s" (gensym*)))
  (bind ?q
        (mq-open ?name
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-getattr: open queue returns integer"
          TRUE
          (integerp ?q))

  (if (not (integerp ?q))
   then
    (return))

  (expect "mq-getattr: invalid descriptor fails"
          FALSE
          (mq-getattr -1))

  (bind ?attr-mf-default (mq-getattr ?q))

  (expect "mq-getattr: default return type is multifield" MULTIFIELD (class ?attr-mf-default))
  (if (not (multifieldp ?attr-mf-default))
   then
    (return))
  (expect "mq-getattr: returned multifield has 4 values" 4 (length$ ?attr-mf-default))
  (if (<> 4 (length$ ?attr-mf-default))
   then
    (return))
  (expect "mq-getattr: first value is 0" 0 (nth$ 1 ?attr-mf-default))
  (expect "mq-getattr: second value is 5" 5 (nth$ 2 ?attr-mf-default))
  (expect "mq-getattr: third value is 64" 64 (nth$ 3 ?attr-mf-default))
  (expect "mq-getattr: fourth value is 0" 0 (nth$ 4 ?attr-mf-default))

  (bind ?attr-mf-explicit (mq-getattr ?q multifield))

  (expect "mq-getattr: explicit multifield return type" TRUE (eq ?attr-mf-default ?attr-mf-explicit))

  (bind ?attr-fact (mq-getattr ?q fact))

  (expect "mq-getattr: fact return type" TRUE (fact-addressp ?attr-fact))
  (if (not (fact-addressp ?attr-fact))
   then
    (return))

  (expect "mq-getattr: flags fact slot is 0" 0 (fact-slot-value ?attr-fact flags))
  (expect "mq-getattr: maxmsg fact slot is 5" 5 (fact-slot-value ?attr-fact maxmsg))
  (expect "mq-getattr: msgsize fact slot is 64" 64 (fact-slot-value ?attr-fact msgsize))
  (expect "mq-getattr: curmsgs fact slot is 0" 0 (fact-slot-value ?attr-fact curmsgs))

  (bind ?attr-custom-fact (mq-getattr ?q fact custom-mq-attr))

  (expect "mq-getattr: fact return type for custom deftemplate" FACT-ADDRESS (class ?attr-custom-fact))
  (if (not (fact-addressp ?attr-custom-fact))
   then
    (return))

  (expect "mq-getattr: custom fact is of deftemplate custom-mq-attr" custom-mq-attr (fact-relation ?attr-custom-fact))
  (expect "mq-getattr: flags fact slot is 0 for custom fact" 0 (fact-slot-value ?attr-custom-fact flags))
  (expect "mq-getattr: maxmsg fact slot is 5 for custom fact" 5 (fact-slot-value ?attr-custom-fact maxmsg))
  (expect "mq-getattr: msgsize fact slot is 64 for custom fact" 64 (fact-slot-value ?attr-custom-fact msgsize))
  (expect "mq-getattr: curmsgs fact slot is 0 for custom fact" 0 (fact-slot-value ?attr-custom-fact curmsgs))

  (bind ?attr-custom-fact-flags (mq-getattr ?q fact custom-mq-attr-flags))

  (expect "mq-getattr: fact return type for custom deftemplate" FACT-ADDRESS (class ?attr-custom-fact-flags))
  (if (not (fact-addressp ?attr-custom-fact-flags))
   then
    (return))

  (expect "mq-getattr: custom fact is of deftemplate custom-mq-attr" custom-mq-attr-flags (fact-relation ?attr-custom-fact-flags))

  (bind ?attr-custom-fact-maxmsg (mq-getattr ?q fact custom-mq-attr-maxmsg))

  (expect "mq-getattr: fact return type for custom deftemplate" FACT-ADDRESS (class ?attr-custom-fact-maxmsg))
  (if (not (fact-addressp ?attr-custom-fact-maxmsg))
   then
    (return))

  (expect "mq-getattr: custom fact is of deftemplate custom-mq-attr" custom-mq-attr-maxmsg (fact-relation ?attr-custom-fact-maxmsg))

  (bind ?attr-custom-fact-msgsize (mq-getattr ?q fact custom-mq-attr-msgsize))

  (expect "mq-getattr: fact return type for custom deftemplate" FACT-ADDRESS (class ?attr-custom-fact-msgsize))
  (if (not (fact-addressp ?attr-custom-fact-msgsize))
   then
    (return))

  (expect "mq-getattr: custom fact is of deftemplate custom-mq-attr" custom-mq-attr-msgsize (fact-relation ?attr-custom-fact-msgsize))

  (bind ?attr-custom-fact-curmsgs (mq-getattr ?q fact custom-mq-attr-curmsgs))

  (expect "mq-getattr: fact return type for custom deftemplate" FACT-ADDRESS (class ?attr-custom-fact-curmsgs))
  (if (not (fact-addressp ?attr-custom-fact-curmsgs))
   then
    (return))

  (expect "mq-getattr: custom fact is of deftemplate custom-mq-attr-curmsgs" custom-mq-attr-curmsgs (fact-relation ?attr-custom-fact-curmsgs))

  ; instances
  (bind ?attr-inst (mq-getattr ?q instance))

  (expect "mq-getattr: instance return type" TRUE (instancep ?attr-inst))
  (if (not (instancep ?attr-inst))
   then
    (return))

  (expect "mq-getattr: flags instance slot is 0" 0 (send ?attr-inst get-flags))
  (expect "mq-getattr: maxmsg instance slot is 5" 5 (send ?attr-inst get-maxmsg))
  (expect "mq-getattr: msgsize instance slot is 64" 64 (send ?attr-inst get-msgsize))
  (expect "mq-getattr: curmsgs instance slot is 0" 0 (send ?attr-inst get-curmsgs))

  ; custom instance defclass
  (bind ?attr-custom-inst (mq-getattr ?q instance CUSTOM-MQ-ATTR))

  (expect "mq-getattr: instance return type for custom deftemplate" TRUE (instancep ?attr-custom-inst))
  (if (not (instance-addressp ?attr-custom-inst))
   then
    (return))

  (expect "mq-getattr: custom instance is of defclass CUSTOM-MQ-ATTR" CUSTOM-MQ-ATTR (class ?attr-custom-inst))
  (expect "mq-getattr: flags instance slot is 0 for custom instance" 0 (send ?attr-custom-inst get-flags))
  (expect "mq-getattr: maxmsg instance slot is 5 for custom instance" 5 (send ?attr-custom-inst get-maxmsg))
  (expect "mq-getattr: msgsize instance slot is 64 for custom instance" 64 (send ?attr-custom-inst get-msgsize))
  (expect "mq-getattr: curmsgs instance slot is 0 for custom instance" 0 (send ?attr-custom-inst get-curmsgs))

  ; custom instance defclass with only one slot
  (bind ?attr-custom-inst-flags (mq-getattr ?q instance CUSTOM-MQ-ATTR-FLAGS))

  (expect "mq-getattr: instance return type for custom deftemplate with just flags slot" TRUE (instancep ?attr-custom-inst-flags))
  (if (not (instance-addressp ?attr-custom-inst-flags))
   then
    (return))

  (expect "mq-getattr: custom instance is of defclass CUSTOM-MQ-ATTR-FLAGS" CUSTOM-MQ-ATTR-FLAGS (class ?attr-custom-inst-flags))
  (expect "mq-getattr: flags instance slot is 0 for custom instance" 0 (send ?attr-custom-inst get-flags))

  (bind ?attr-custom-inst-maxmsg (mq-getattr ?q instance CUSTOM-MQ-ATTR-MAXMSG))

  (expect "mq-getattr: instance return type for custom deftemplate with just maxmsg slot" TRUE (instancep ?attr-custom-inst-maxmsg))
  (if (not (instance-addressp ?attr-custom-inst-maxmsg))
   then
    (return))

  (expect "mq-getattr: custom instance is of defclass CUSTOM-MQ-ATTR-MAXMSG" CUSTOM-MQ-ATTR-MAXMSG (class ?attr-custom-inst-maxmsg))
  (expect "mq-getattr: maxmsg instance slot is 5 for custom instance" 5 (send ?attr-custom-inst get-maxmsg))

  (bind ?attr-custom-inst-msgsize (mq-getattr ?q instance CUSTOM-MQ-ATTR-MSGSIZE))

  (expect "mq-getattr: instance return type for custom deftemplate with just msgsize slot" TRUE (instancep ?attr-custom-inst-msgsize))
  (if (not (instance-addressp ?attr-custom-inst-msgsize))
   then
    (return))

  (expect "mq-getattr: custom instance is of defclass CUSTOM-MQ-ATTR-MSGSIZE" CUSTOM-MQ-ATTR-MSGSIZE (class ?attr-custom-inst-msgsize))
  (expect "mq-getattr: msgsize instance slot is 64 for custom instance" 64 (send ?attr-custom-inst get-msgsize))

  (bind ?attr-custom-inst-curmsgs (mq-getattr ?q instance CUSTOM-MQ-ATTR-CURMSGS))

  (expect "mq-getattr: instance return type for custom deftemplate with just curmsgs slot" TRUE (instancep ?attr-custom-inst-curmsgs))
  (if (not (instance-addressp ?attr-custom-inst-curmsgs))
   then
    (return))

  (expect "mq-getattr: custom instance is of defclass CUSTOM-MQ-ATTR-CURMSGS" CUSTOM-MQ-ATTR-CURMSGS (class ?attr-custom-inst-curmsgs))
  (expect "mq-getattr: curmsgs instance slot is 0 for custom instance" 0 (send ?attr-custom-inst-curmsgs get-curmsgs))

  (expect "mq-getattr: close descriptor"
          TRUE
          (mq-close ?q))

  (expect "mq-getattr: unlink queue"
          TRUE
          (mq-unlink ?name))

  (printout t crlf))

; ----------------------------------------------------------------------
; Test driver for mq-setattr
; ----------------------------------------------------------------------

(deffunction run-mq-setattr-tests ()
  (bind ?name (format nil "/mq-setattr-%s" (gensym*)))
  (bind ?q
        (mq-open ?name
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-setattr: open queue returns integer"
          INTEGER
          (class ?q))

  (if (not (integerp ?q))
   then
    (return))

  (bind ?orig-attr (mq-getattr ?q))

  (expect "mq-setattr: mq_attr multifield contains non-integer fails"
          FALSE
          (mq-setattr ?q (create$ 0 1 "x" 3)))

  (expect "mq-setattr: invalid descriptor mq_setattr failure"
          FALSE
          (mq-setattr -1 (create$ 0 5 64 0)))

  (bind ?old-mf-default (mq-setattr ?q (create$ 0 11 65 1)))

  (expect "mq-setattr: default return type is multifield" MULTIFIELD (class ?old-mf-default))

  (if (not (multifieldp ?old-mf-default))
   then
    (return))

  (expect "mq-setattr: returned multifield has 4 values" 4 (length$ ?old-mf-default))

  (expect "mq-setattr: default old attr matches original attr" ?orig-attr ?old-mf-default)

  (bind ?attr-after-1 (mq-getattr ?q))

  (expect "mq-setattr: attr after default return type is multifield" MULTIFIELD (class ?attr-after-1))

  (if (not (multifieldp ?attr-after-1))
   then
    (return))

  (expect "mq-setattr: attr after default returned multifield has 4 values" 4 (length$ ?attr-after-1))

  (expect "mq-setattr: getattr proves the changed attrs" (create$ 0 5 64 0) ?attr-after-1)

  (bind ?old-mf-explicit
        (mq-setattr ?q (create$ 0 5 64 0) multifield))

  (expect "mq-setattr: explicit multifield return type is multifield" MULTIFIELD (class ?old-mf-explicit))

  (if (not (multifieldp ?old-mf-explicit))
   then
    (return))

  (expect "mq-setattr: explicit old attr matches attr after first set"
          TRUE
          (and
            (= (nth$ 1 ?old-mf-explicit) (nth$ 1 ?attr-after-1))
            (= (nth$ 2 ?old-mf-explicit) (nth$ 2 ?attr-after-1))
            (= (nth$ 3 ?old-mf-explicit) (nth$ 3 ?attr-after-1))
            (= (nth$ 4 ?old-mf-explicit) (nth$ 4 ?attr-after-1))))

  (bind ?attr-after-2 (mq-getattr ?q))

  (bind ?fact-ok
        (assert (mq-attr (flags 0)
                         (maxmsg 10)
                         (msgsize 128)
                         (curmsgs 0))))

  (bind ?old-fact
        (mq-setattr ?q ?fact-ok fact))

  (expect "mq-setattr: fact return type"
          TRUE
          (fact-addressp ?old-fact))

  (expect "mq-setattr: fact has integer slots"
          TRUE
          (and
            (integerp (fact-slot-value ?old-fact flags))
            (integerp (fact-slot-value ?old-fact maxmsg))
            (integerp (fact-slot-value ?old-fact msgsize))
            (integerp (fact-slot-value ?old-fact curmsgs))))

  (expect "mq-setattr: old fact attr matches previous attr"
          TRUE
          (and
            (= (fact-slot-value ?old-fact flags)   (nth$ 1 ?attr-after-2))
            (= (fact-slot-value ?old-fact maxmsg)  (nth$ 2 ?attr-after-2))
            (= (fact-slot-value ?old-fact msgsize) (nth$ 3 ?attr-after-2))
            (= (fact-slot-value ?old-fact curmsgs) (nth$ 4 ?attr-after-2))))

  (bind ?attr-after-3 (mq-getattr ?q))

  (expect "mq-setattr: attr after fact set remains 4 integers"
          TRUE
          (and
            (multifieldp ?attr-after-3)
            (= (length$ ?attr-after-3) 4)
            (integerp (nth$ 1 ?attr-after-3))
            (integerp (nth$ 2 ?attr-after-3))
            (integerp (nth$ 3 ?attr-after-3))
            (integerp (nth$ 4 ?attr-after-3))))

  (make-instance [mq-attr-inst-set-ok] of MQ-ATTR
    (flags 0)
    (maxmsg 10)
    (msgsize 256)
    (curmsgs 0))

  (bind ?old-inst
        (mq-setattr ?q (instance-address [mq-attr-inst-set-ok]) instance))

  (expect "mq-setattr: instance return type"
          TRUE
          (instancep ?old-inst))

  (expect "mq-setattr: instance has integer slots"
          TRUE
          (and
            (integerp (send ?old-inst get-flags))
            (integerp (send ?old-inst get-maxmsg))
            (integerp (send ?old-inst get-msgsize))
            (integerp (send ?old-inst get-curmsgs))))

  (expect "mq-setattr: old instance attr mirrors attr after fact set"
          TRUE
          (and
            (= (send ?old-inst get-flags)   (nth$ 1 ?attr-after-3))
            (= (send ?old-inst get-maxmsg)  (nth$ 2 ?attr-after-3))
            (= (send ?old-inst get-msgsize) (nth$ 3 ?attr-after-3))
            (= (send ?old-inst get-curmsgs) (nth$ 4 ?attr-after-3))))

  (bind ?old-unknown
        (mq-setattr ?q (create$ 0 10 64 0) unknown-rtype))

  (expect "mq-setattr: unknown rtype falls back to multifield"
          TRUE
          (and (multifieldp ?old-unknown)
               (= (length$ ?old-unknown) 4)
               (integerp (nth$ 1 ?old-unknown))
               (integerp (nth$ 2 ?old-unknown))
               (integerp (nth$ 3 ?old-unknown))
               (integerp (nth$ 4 ?old-unknown))))

  (expect "mq-setattr: close descriptor"
          TRUE
          (mq-close ?q))

  (expect "mq-setattr: unlink queue"
          TRUE
          (mq-unlink ?name))

  (printout t crlf))

; ----------------------------------------------------------------------
; Test driver for mq-open / mq-close / mq-unlink / mq-notify
; ----------------------------------------------------------------------

(deffunction run-mq-open-tests ()
  (bind ?name1 (format nil "/mq-two-args-%s" (gensym*)))
  (bind ?q1 (mq-open ?name1 (create$ O_CREAT O_EXCL O_RDWR) 0600))

  (expect "mq-open: 2-arg open returns integer"
          TRUE
          (integerp ?q1))

  (bind ?name2 (format nil "/mq-mf-oflags-int-mode-mf-attr-%s" (gensym*)))
  (bind ?q2
        (mq-open ?name2
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 10 1024 0)))

  (expect "mq-open: multifield oflags, integer mode, mf attr returns integer"
          TRUE
          (integerp ?q2))

  (refute "mq-open: multifield oflags, integer mode, mf attr not FALSE"
          FALSE
          ?q2)

  (expect "mq-open: O_CREAT|O_EXCL on existing name fails"
          FALSE
          (mq-open ?name2
                   (create$ O_CREAT O_EXCL O_RDWR)
                   600
                   (create$ 0 10 1024 0)))

  (bind ?name3 (format nil "/mq-oflag-int-%s" (gensym*)))
  (expect "mq-open: oflag as integer (mq_open may fail, but integer branch hit)"
          FALSE
          (mq-open ?name3 0))

  (bind ?name4 (format nil "/mq-oflag-symbol-%s" (gensym*)))
  (bind ?q4 (mq-open ?name4 O_CREAT 600))
  (expect "mq-open: oflag as valid symbol"
          TRUE
          (integerp ?q4))

  (bind ?name5 (format nil "/mq-oflag-mf-bad-type-%s" (gensym*)))
  (expect "mq-open: oflag multifield contains non-symbol"
          FALSE
          (mq-open ?name5
                   (create$ O_RDONLY 1)))

  (bind ?name6 (format nil "/mq-oflag-mf-bad-symbol-%s" (gensym*)))
  (expect "mq-open: oflag multifield contains invalid symbol"
          FALSE
          (mq-open ?name6
                   (create$ O_RDONLY BAD_FLAG)))

  (bind ?name7 (format nil "/mq-mode-symbol-%s" (gensym*)))
  (bind ?q7
        (mq-open ?name7
                 (create$ O_CREAT O_EXCL O_RDWR)
                 S_IRUSR
                 (create$ 0 5 256 0)))

  (expect "mq-open: mode as symbol"
          TRUE
          (integerp ?q7))

  (bind ?name8 (format nil "/mq-mode-mf-int-syms-%s" (gensym*)))
  (bind ?q8
        (mq-open ?name8
                 (create$ O_CREAT O_EXCL O_RDWR)
                 (create$ 256 S_IRUSR S_IWUSR)
                 (create$ 0 5 64 0)))

  (expect "mq-open: mode as multifield (int+symbols)"
          TRUE
          (integerp ?q8))

  (bind ?name9 (format nil "/mq-mode-bad-symbol-%s" (gensym*)))
  (expect "mq-open: invalid mode symbol"
          FALSE
          (mq-open ?name9
                   (create$ O_CREAT O_EXCL O_RDWR)
                   BADMODE
                   (create$ 0 5 64 0)))

  (bind ?name10 (format nil "/mq-mode-mf-bad-type-%s" (gensym*)))
  (expect "mq-open: mode multifield contains invalid element type"
          FALSE
          (mq-open ?name10
                   (create$ O_CREAT O_EXCL O_RDWR)
                   (create$ S_IRUSR "bad" 256)
                   (create$ 0 5 64 0)))

  (bind ?name11 (format nil "/mq-attr-mf-short-%s" (gensym*)))
  (bind ?short-q (mq-open ?name11
                   (create$ O_CREAT O_EXCL O_RDWR)
                   600
                   (create$ 0 1 2)))
  (expect "mq-open: mq_attr multifield can be less than 4 values"
          INTEGER
          (class ?short-q))

  (bind ?name12 (format nil "/mq-attr-mf-bad-type-%s" (gensym*)))
  (expect "mq-open: mq_attr multifield contains non-integer"
          FALSE
          (mq-open ?name12
                   (create$ O_CREAT O_EXCL O_RDWR)
                   600
                   (create$ 0 1 "x" 3)))

  (bind ?fact-ok
        (assert (mq-attr (flags 0)
                         (maxmsg 10)
                         (msgsize 512)
                         (curmsgs 0))))

  (bind ?name13 (format nil "/mq-attr-fact-%s" (gensym*)))
  (bind ?q13
        (mq-open ?name13
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 ?fact-ok))

  (expect "mq-open: mq_attr from fact"
          TRUE
          (integerp ?q13))

  (if (integerp ?q13)
   then
    (bind ?a13 (mq-getattr ?q13))
    (expect "mq-open: mq_attr fact reflected in getattr"
            TRUE
            (and
              (multifieldp ?a13)
              (= (length$ ?a13) 4)
              (integerp (nth$ 1 ?a13))
              (integerp (nth$ 2 ?a13))
              (integerp (nth$ 3 ?a13))
              (integerp (nth$ 4 ?a13))))
    (expect "mq-open: fact maxmsg/msgsize preserved"
            TRUE
            (and
              (= (nth$ 2 ?a13) (fact-slot-value ?fact-ok maxmsg))
              (= (nth$ 3 ?a13) (fact-slot-value ?fact-ok msgsize)))))

  (bind ?fact-bad
        (assert (mq-attr (flags "bad")
                         (maxmsg 10)
                         (msgsize 512)
                         (curmsgs 0))))

  (bind ?name14 (format nil "/mq-attr-bad-fact-%s" (gensym*)))
  (expect "mq-open: mq_attr from bad fact fails"
          FALSE
          (mq-open ?name14
                   (create$ O_CREAT O_EXCL O_RDWR)
                   600
                   ?fact-bad))

  (make-instance [mq-attr-inst-ok] of MQ-ATTR
    (flags 0)
    (maxmsg 10)
    (msgsize 128)
    (curmsgs 0))

  (bind ?name15 (format nil "/mq-attr-instance-%s" (gensym*)))
  (bind ?q15
        (mq-open ?name15
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (instance-address [mq-attr-inst-ok])))

  (expect "mq-open: mq_attr from instance"
          TRUE
          (integerp ?q15))

  (if (integerp ?q15)
   then
    (bind ?a15 (mq-getattr ?q15))
    (expect "mq-open: instance attr reflected in getattr"
            TRUE
            (and
              (multifieldp ?a15)
              (= (length$ ?a15) 4)
              (integerp (nth$ 1 ?a15))
              (integerp (nth$ 2 ?a15))
              (integerp (nth$ 3 ?a15))
              (integerp (nth$ 4 ?a15))))
    (expect "mq-open: instance maxmsg/msgsize preserved"
            TRUE
            (and
              (= (nth$ 2 ?a15) (send [mq-attr-inst-ok] get-maxmsg))
              (= (nth$ 3 ?a15) (send [mq-attr-inst-ok] get-msgsize)))))

  (make-instance [mq-attr-inst-bad] of MQ-ATTR
    (flags "bad")
    (maxmsg 10)
    (msgsize 128)
    (curmsgs 0))

  (bind ?name16 (format nil "/mq-attr-bad-instance-%s" (gensym*)))
  (expect "mq-open: mq_attr from bad instance fails"
          FALSE
          (mq-open ?name16
                   (create$ O_CREAT O_EXCL O_RDWR)
                   600
                   (instance-address [mq-attr-inst-bad])))

  ; mq-notify tests

  (if (integerp ?q1)
   then
    (expect "mq-notify: basic registration with NULL sigevent"
            TRUE
            (mq-notify ?q1)))

  (if (integerp ?q2)
   then
    (expect "mq-notify: sigevent from multifield"
            TRUE
            (mq-notify ?q2 (create$ 0 10 42))))

  (bind ?sev-fact-ok
        (assert (mq-sigevent (notify 0)
                             (signo 10)
                             (value 42))))

  (if (integerp ?q4)
   then
    (expect "mq-notify: sigevent from fact"
            TRUE
            (mq-notify ?q4 ?sev-fact-ok)))

  (make-instance [mq-sigevent-inst-ok] of mq-sigevent-class
    (notify 0)
    (signo 10)
    (value 42))

  (if (integerp ?q7)
   then
    (expect "mq-notify: sigevent from instance"
            TRUE
            (mq-notify ?q7 (instance-address [mq-sigevent-inst-ok]))))

  (if (integerp ?q1)
   then
    (expect "mq-notify: sigevent multifield too short"
            FALSE
            (mq-notify ?q1 (create$ 0 10))))

  (if (integerp ?q1)
   then
    (expect "mq-notify: sigevent multifield contains non-integer"
            FALSE
            (mq-notify ?q1 (create$ 0 "x" 10))))

  (bind ?sev-fact-bad
        (assert (mq-sigevent (notify "bad")
                             (signo 10)
                             (value 42))))

  (if (integerp ?q1)
   then
    (expect "mq-notify: sigevent from bad fact fails"
            FALSE
            (mq-notify ?q1 ?sev-fact-bad)))

  (make-instance [mq-sigevent-inst-bad] of mq-sigevent-class
    (notify "bad")
    (signo 10)
    (value 42))

  (if (integerp ?q1)
   then
    (expect "mq-notify: sigevent from bad instance fails"
            FALSE
            (mq-notify ?q1 (instance-address [mq-sigevent-inst-bad]))))

  (expect "mq-notify: invalid descriptor fails"
          FALSE
          (mq-notify -1))

  ; mq-close tests + cleanup

  (if (integerp ?q1)
   then
    (expect "mq-close: valid descriptor"
            TRUE
            (mq-close ?q1))
    (expect "mq-close: closing already closed descriptor fails"
            FALSE
            (mq-close ?q1))
   else
    (expect "mq-close: invalid descriptor fails"
            FALSE
            (mq-close -1)))

  (if (integerp ?q2) then (mq-close ?q2))
  (if (integerp ?q4) then (mq-close ?q4))
  (if (integerp ?q7) then (mq-close ?q7))
  (if (integerp ?q8) then (mq-close ?q8))
  (if (integerp ?q13) then (mq-close ?q13))
  (if (integerp ?q15) then (mq-close ?q15))
  (if (integerp ?short-q) then (mq-close ?short-q))

  ; mq-unlink tests + cleanup

  (if (integerp ?q1)
   then
    (expect "mq-unlink: existing queue succeeds"
            TRUE
            (mq-unlink ?name1)))

  (if (integerp ?q2) then (mq-unlink ?name2))
  (if (integerp ?q4) then (mq-unlink ?name4))
  (if (integerp ?q7) then (mq-unlink ?name7))
  (if (integerp ?q8) then (mq-unlink ?name8))
  (if (integerp ?q13) then (mq-unlink ?name13))
  (if (integerp ?q15) then (mq-unlink ?name15))
  (if (integerp ?short-q) then (mq-unlink ?name11))

  (expect "mq-unlink: non-existent queue fails"
          FALSE
          (mq-unlink (format nil "/mq-unlink-non-existent-%s" (gensym*))))

  (printout t crlf))

; ----------------------------------------------------------------------
; Test driver for mq-send / mq-receive (+ mq_timedsend / mq_timedreceive)
; ----------------------------------------------------------------------

(deffunction run-mq-send-receive-tests ()
  (bind ?name (format nil "/mq-send-recv-%s" (gensym*)))
  (bind ?q
        (mq-open ?name
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 10 64 0)))

  (expect "mq-send/recv: open queue returns integer"
          TRUE
          (integerp ?q))

  (if (not (integerp ?q))
   then
    (return))

  ; ---------------- MqSend happy paths ----------------

  (expect "mq-send: string descriptor default priority/len"
          TRUE
          (mq-send ?q "mf-default string"))

  (expect "mq-send: symbol descriptor default priority/len"
          TRUE
          (mq-send ?q mf-default-sym))

  (expect "mq-send: multifield descriptor default priority/len"
          TRUE
          (mq-send ?q (create$ "mf-default")))

  (expect "mq-send: multifield descriptor with embedded priority"
          TRUE
          (mq-send ?q (create$ "mf-embedded-priority" 5)))

  (expect "mq-send: explicit priority override"
          TRUE
          (mq-send ?q (create$ "mf-explicit-priority" 1) 9))

  (expect "mq-send: explicit length override"
          TRUE
          (mq-send ?q (create$ "truncate-me") 5))

  (bind ?msg-fact-ok
        (assert (mq-message (data "fact-ok")
                            (priority 7))))

  (expect "mq-send: fact descriptor success"
          TRUE
          (mq-send ?q ?msg-fact-ok))

  (bind ?msg-fact-nopriority
        (assert (mq-message (data "fact-nopriority")
                            (priority "not-int"))))

  (expect "mq-send: fact descriptor non-integer priority uses default"
          TRUE
          (mq-send ?q ?msg-fact-nopriority))

  (make-instance [mq-msg-inst-ok] of MQ-MESSAGE
    (data "inst-ok")
    (priority 4))

  (expect "mq-send: instance descriptor success"
          TRUE
          (mq-send ?q (instance-address [mq-msg-inst-ok])))

  (make-instance [mq-msg-inst-nopriority] of MQ-MESSAGE
    (data "inst-nopriority")
    (priority "not-int"))

  (expect "mq-send: instance descriptor non-integer priority uses default"
          TRUE
          (mq-send ?q (instance-address [mq-msg-inst-nopriority])))

  (bind ?attr-before (mq-getattr ?q))
  (bind ?curmsgs-before (nth$ 4 ?attr-before))

  (expect "mq-send: curmsgs reflects enqueued messages"
          TRUE
          (= ?curmsgs-before 10))

  ; ---------------- MqSend error paths ----------------

  (expect "mq-send: empty multifield descriptor fails"
          FALSE
          (mq-send ?q (create$)))

  (expect "mq-send: multifield descriptor non-string first element fails"
          FALSE
          (mq-send ?q (create$ 123)))

  (expect "mq-send: multifield descriptor non-integer priority fails"
          FALSE
          (mq-send ?q (create$ "mf-bad-priority" "priority")))

  (bind ?msg-fact-bad
        (assert (mq-message (data 123)
                            (priority 1))))

  (expect "mq-send: fact descriptor non-string data fails"
          FALSE
          (mq-send ?q ?msg-fact-bad))

  (make-instance [mq-msg-inst-bad] of MQ-MESSAGE
    (data 123)
    (priority 1))

  (expect "mq-send: instance descriptor non-string data fails"
          FALSE
          (mq-send ?q (instance-address [mq-msg-inst-bad])))

  (expect "mq-send: explicit negative length fails"
          FALSE
          (mq-send ?q (create$ "negative-len") -1))

  (expect "mq-send: invalid descriptor triggers mq_send failure"
          FALSE
          (mq-send -1 (create$ "invalid-descriptor")))

  ; ---------------- mq_timedsend: invalid descriptor + length with timespec ----------------

  (expect "mq-send: invalid descriptor with timespec"
          FALSE
          (mq-send -1 (create$ "bad-desc-timed") 5 (create$ 0 0)))

  (expect "mq-send: negative explicit length with timespec fails"
          FALSE
          (mq-send ?q (create$ "neg-len-timed") -5 (create$ 0 0)))

  ; ---------------- mq_timedsend: tests on a dedicated queue ----------------

  (bind ?name-ts (format nil "/mq-send-timed-%s" (gensym*)))
  (bind ?q-ts
        (mq-open ?name-ts
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 10 64 0)))

  (expect "mq-send: mq_timedsend test queue open"
          TRUE
          (integerp ?q-ts))

  (if (integerp ?q-ts)
   then
    (bind ?attr-ts-before (mq-getattr ?q-ts))
    (bind ?curmsgs-ts-before (nth$ 4 ?attr-ts-before))

    ; ---- ParseTimespecFromValue failure paths via mq-send ----

    (expect "mq-send: timespec multifield contains non-integer"
            FALSE
            (mq-send ?q-ts (create$ "mf-bad-timed") 5 (create$ "sec" 0)))

    (expect "mq-send: timespec multifield nsec out of range"
            FALSE
            (mq-send ?q-ts (create$ "mf-bad-timed2") 5 (create$ 0 1000000000)))

    (bind ?ts-bad-fact
          (assert (mq-timespec (sec "bad")
                               (nsec 0))))

    (expect "mq-send: timespec fact contains non-integer"
            FALSE
            (mq-send ?q-ts (create$ "mf-bad-timed3") 5 ?ts-bad-fact))

    (make-instance [mq-ts-inst-bad] of mq-timespec-class
      (sec 1)
      (nsec "bad"))

    (expect "mq-send: timespec instance contains non-integer"
            FALSE
            (mq-send ?q-ts (create$ "mf-bad-timed4") 5 (instance-address [mq-ts-inst-bad])))

    ; ---- mq_timedsend success paths ----

    (bind ?ts-ok-mf (create$ 2000000000 0))

    (expect "mq-send: mq_timedsend with multifield timespec succeeds"
            TRUE
            (mq-send ?q-ts (create$ "timedsend-mf" 3) 12 ?ts-ok-mf))

    (bind ?ts-ok-fact
          (assert (mq-timespec (sec 2000000000)
                               (nsec 0))))

    (expect "mq-send: mq_timedsend with fact timespec succeeds"
            TRUE
            (mq-send ?q-ts (create$ "timedsend-fact" 4) 14 ?ts-ok-fact))

    (make-instance [mq-ts-inst-good] of mq-timespec-class
      (sec 2000000000)
      (nsec 0))

    (expect "mq-send: mq_timedsend with instance timespec succeeds"
            TRUE
            (mq-send ?q-ts (create$ "timedsend-inst" 5) 16 (instance-address [mq-ts-inst-good])))

    (bind ?attr-ts-after (mq-getattr ?q-ts))
    (bind ?curmsgs-ts-after (nth$ 4 ?attr-ts-after))

    (expect "mq-send: mq_timedsend calls increased curmsgs by +3 on timed queue"
            TRUE
            (= ?curmsgs-ts-after (+ ?curmsgs-ts-before 3)))

    (expect "mq-send: close timed queue descriptor"
            TRUE
            (mq-close ?q-ts))

    (expect "mq-send: unlink timed queue"
            TRUE
            (mq-unlink ?name-ts)))

  ; ---------------- MqReceive error paths ----------------

  (expect "mq-receive: mq_getattr failure on invalid descriptor"
          FALSE
          (mq-receive -1))

  (bind ?name-empty (format nil "/mq-receive-empty-%s" (gensym*)))
  (bind ?q-empty
        (mq-open ?name-empty
                 (create$ O_CREAT O_EXCL O_RDONLY O_NONBLOCK)
                 600
                 (create$ 0 5 64 0)))

  (if (integerp ?q-empty)
   then
    (expect "mq-receive: mq_receive failure on empty non-blocking queue"
            FALSE
            (mq-receive ?q-empty))
    (mq-close ?q-empty)
    (mq-unlink ?name-empty))

  (expect "mq-receive: non-positive length fails"
          FALSE
          (mq-receive ?q 0 multifield))

  ; --- bad timespec descriptors (ParseTimespecFromValue failures) ---

  (expect "mq-receive: timespec multifield contains non-integer"
          FALSE
          (mq-receive ?q 64 multifield (create$ "sec" 0)))

  (expect "mq-receive: timespec multifield nsec out of range fails"
          FALSE
          (mq-receive ?q 64 multifield (create$ 0 1000000000)))

  ; --- mq_timedreceive failure (ETIMEDOUT using past absolute time) ---

  (bind ?name-timed-empty (format nil "/mq-receive-timed-empty-%s" (gensym*)))
  (bind ?q-timed-empty
        (mq-open ?name-timed-empty
                 (create$ O_CREAT O_EXCL O_RDONLY)
                 600
                 (create$ 0 5 64 0)))

  (if (integerp ?q-timed-empty)
   then
    (bind ?ts-past (create$ 0 0))
    (expect "mq-receive: mq_timedreceive failure on empty queue (multifield timespec)"
            FALSE
            (mq-receive ?q-timed-empty 64 ?ts-past multifield))
    (mq-close ?q-timed-empty)
    (mq-unlink ?name-timed-empty))

  ; ---------------- mq_timedreceive success paths on separate queue ----------------

  (bind ?name-timed (format nil "/mq-receive-timed-%s" (gensym*)))
  (bind ?q-timed
        (mq-open ?name-timed
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 10 64 0)))

  (expect "mq-receive: mq_timedreceive test queue open"
          TRUE
          (integerp ?q-timed))

  (if (integerp ?q-timed)
   then
    ; enqueue four messages
    (expect "mq-receive: mq_timedreceive send #1"
            TRUE
            (mq-send ?q-timed (create$ "timed-mf" 1)))
    (expect "mq-receive: mq_timedreceive send #2"
            TRUE
            (mq-send ?q-timed (create$ "timed-str" 2)))
    (expect "mq-receive: mq_timedreceive send #3"
            TRUE
            (mq-send ?q-timed (create$ "timed-sym" 3)))
    (expect "mq-receive: mq_timedreceive send #4"
            TRUE
            (mq-send ?q-timed (create$ "timed-fact" 4)))
    (expect "mq-receive: mq_timedreceive send #5"
            TRUE
            (mq-send ?q-timed (create$ "timed-inst" 5)))
    (expect "mq-receive: mq_timedreceive send #6"
            TRUE
            (mq-send ?q-timed (create$ "timed-inst-name" 6)))

    ; 1) timespec from multifield (non-instance rtype)
    (bind ?ts-future-mf (create$ 2000000000 0))
    (bind ?tmf (mq-receive ?q-timed 64 ?ts-future-mf multifield))

    (expect "mq-receive: mq_timedreceive with multifield timespec"
            TRUE
            (and (multifieldp ?tmf)
                 (= (length$ ?tmf) 2)
                 (eq (nth$ 1 ?tmf) "timed-inst-name")
                 (integerp (nth$ 2 ?tmf))))

    ; 2) timespec from fact (rtype = fact)
    (bind ?ts-fact
          (assert (mq-timespec (sec 2000000000)
                               (nsec 0))))

    (bind ?tf (mq-receive ?q-timed 64 ?ts-fact fact))

    (expect "mq-receive: mq_timedreceive with fact timespec"
            TRUE
            (and (fact-addressp ?tf)
                 (eq (fact-slot-value ?tf data) "timed-inst")
                 (integerp (fact-slot-value ?tf priority))))

    ; 3) timespec from instance as 4th arg (rtype = instance, no name)
    (make-instance [mq-ts-inst] of mq-timespec-class
      (sec 2000000000)
      (nsec 0))

    (bind ?ti1 (mq-receive ?q-timed 64 (instance-address [mq-ts-inst]) instance))

    (expect "mq-receive: mq_timedreceive with instance timespec (no name)"
            TRUE
            (and (instancep ?ti1)
                 (eq (send ?ti1 get-data) "timed-fact")
                 (integerp (send ?ti1 get-priority))))

    ; 4) instance-name + timespec as 5th arg
    (bind ?ts-future-mf2 (create$ 2000000000 0))
    (bind ?ti2 (mq-receive ?q-timed 64 ?ts-future-mf2 instance timed-inst-name))

    (expect "mq-receive: mq_timedreceive with instance-name and multifield timespec"
            TRUE
            (and (instancep ?ti2)
                 (eq (send ?ti2 get-data) "timed-sym")
                 (integerp (send ?ti2 get-priority))))

    ; 5) str
    (bind ?ts-future-mf2 (create$ 2000000000 0))
    (bind ?ti2 (mq-receive ?q-timed 64 ?ts-future-mf2 string))

    (expect "mq-receive: mq_timedreceive with string and multifield timespec"
            TRUE
            (and (stringp ?ti2)
	    	 (eq "timed-str" ?ti2)))

    ; 6) sym
    (bind ?ts-future-mf2 (create$ 2000000000 0))
    (bind ?ti2 (mq-receive ?q-timed 64 ?ts-future-mf2 symbol))

    (expect "mq-receive: mq_timedreceive with multifield and multifield timespec"
            TRUE
            (and (symbolp ?ti2) (eq timed-mf ?ti2)))

    (expect "mq-receive: mq_timedreceive test queue empty after 6 receives"
            TRUE
            (eq (nth$ 4 (mq-getattr ?q-timed)) 0))

    (mq-close ?q-timed)
    (mq-unlink ?name-timed))

  ; ---------------- MqReceive happy paths (blocking / normal) ----------------

  (bind ?m1 (mq-receive ?q))

  (expect "mq-receive: default return string"
          TRUE
          (stringp ?m1))

  (bind ?m1s (mq-receive ?q string))

  (expect "mq-receive: return string"
          TRUE
          (stringp ?m1s))

  (bind ?m1sy (mq-receive ?q symbol))

  (expect "mq-receive: return symbol"
          TRUE
          (symbolp ?m1sy))

  (bind ?m2 (mq-receive ?q multifield))

  (expect "mq-receive: explicit multifield return type"
          TRUE
          (and (multifieldp ?m2)
               (= (length$ ?m2) 2)
               (lexemep (nth$ 1 ?m2))
               (integerp (nth$ 2 ?m2))))

  (expect "mq-receive: explicit length branch"
          FALSE
          (mq-receive ?q 16 multifield))

  (bind ?f1 (mq-receive ?q fact))

  (expect "mq-receive: fact return type"
          TRUE
          (fact-addressp ?f1))

  (expect "mq-receive: fact has data/priority slots"
          TRUE
          (and
            (lexemep (fact-slot-value ?f1 data))
            (integerp (fact-slot-value ?f1 priority))))

  (bind ?i1 (mq-receive ?q instance))

  (expect "mq-receive: instance return type"
          TRUE
          (instancep ?i1))

  (expect "mq-receive: instance has data/priority slots"
          TRUE
          (and
            (lexemep (send ?i1 get-data))
            (integerp (send ?i1 get-priority))))

  (bind ?attr-after (mq-getattr ?q))

  (expect "mq-receive: curmsgs decreased by 6"
          TRUE
          (= (nth$ 4 ?attr-after) (- ?curmsgs-before 6)))

  ; ---------------- cleanup for main send/receive queue ----------------

  (expect "mq-send/recv: close descriptor"
          TRUE
          (mq-close ?q))

  (expect "mq-send/recv: unlink queue"
          TRUE
          (mq-unlink ?name))

  (printout t crlf))

; ----------------------------------------------------------------------
; Multi-queue mq_timedreceive tests (non-blocking empty queues)
; ----------------------------------------------------------------------

(deffunction run-mq-multi-queue-timedreceive-tests ()
  (bind ?base (gensym*))

  (bind ?name1 (format nil "/mq-multi-1-%s" ?base))
  (bind ?name2 (format nil "/mq-multi-2-%s" ?base))
  (bind ?name3 (format nil "/mq-multi-3-%s" ?base))

  (bind ?q1
        (mq-open ?name1
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (bind ?q2
        (mq-open ?name2
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (bind ?q3
        (mq-open ?name3
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (expect "multi-queue: q1 open returns integer"
          TRUE
          (integerp ?q1))

  (expect "multi-queue: q2 open returns integer"
          TRUE
          (integerp ?q2))

  (expect "multi-queue: q3 open returns integer"
          TRUE
          (integerp ?q3))

  (if (or (not (integerp ?q1))
          (not (integerp ?q2))
          (not (integerp ?q3)))
   then
    (if (integerp ?q1) then (mq-close ?q1) (mq-unlink ?name1))
    (if (integerp ?q2) then (mq-close ?q2) (mq-unlink ?name2))
    (if (integerp ?q3) then (mq-close ?q3) (mq-unlink ?name3))
    (return))

  ; enqueue on first queue only
  (expect "multi-queue: send to q1 succeeds"
          TRUE
          (mq-send ?q1 (create$ "multi-q1-msg" 1)))

  (bind ?ts-future (create$ 2000000000 0))
  (bind ?ts-past   (create$ 0 0))

  ; timedreceive on q1 (has message)
  (bind ?mq1 (mq-receive ?q1 64 ?ts-future multifield))

  (expect "multi-queue: q1 timedreceive returns message"
          TRUE
          (and (multifieldp ?mq1)
               (= (length$ ?mq1) 2)
               (eq (nth$ 1 ?mq1) "multi-q1-msg")
               (integerp (nth$ 2 ?mq1))))

  ; timedreceive on empty queues with past absolute timeout (non-blocking)
  (expect "multi-queue: q2 timedreceive timeout on empty queue"
          FALSE
          (mq-receive ?q2 64 ?ts-past multifield))

  (expect "multi-queue: q3 timedreceive timeout on empty queue"
          FALSE
          (mq-receive ?q3 64 ?ts-past multifield))

  ; ensure q2/q3 remain empty and q1 is empty after receive
  (bind ?attr1 (mq-getattr ?q1))
  (bind ?attr2 (mq-getattr ?q2))
  (bind ?attr3 (mq-getattr ?q3))

  (expect "multi-queue: q1 empty after timedreceive"
          TRUE
          (= (nth$ 4 ?attr1) 0))

  (expect "multi-queue: q2 remains empty"
          TRUE
          (= (nth$ 4 ?attr2) 0))

  (expect "multi-queue: q3 remains empty"
          TRUE
          (= (nth$ 4 ?attr3) 0))

  ; cleanup
  (expect "multi-queue: close q1"
          TRUE
          (mq-close ?q1))

  (expect "multi-queue: close q2"
          TRUE
          (mq-close ?q2))

  (expect "multi-queue: close q3"
          TRUE
          (mq-close ?q3))

  (expect "multi-queue: unlink q1"
          TRUE
          (mq-unlink ?name1))

  (expect "multi-queue: unlink q2"
          TRUE
          (mq-unlink ?name2))

  (expect "multi-queue: unlink q3"
          TRUE
          (mq-unlink ?name3))

  (printout t crlf))

; ----------------------------------------------------------------------
; Generic message structures for custom defclass/deftemplate mq-send tests
; ----------------------------------------------------------------------

(deftemplate custom-mq-message
  (slot data)
  (slot priority))

(defclass CUSTOM-MQ-MESSAGE (is-a USER)
  (slot data (type LEXEME))
  (slot priority (type INTEGER)))

; ----------------------------------------------------------------------
; Generic timespec structures for ParseTimespecFromValue tests
; ----------------------------------------------------------------------

(deftemplate generic-timespec
  (slot sec)
  (slot nsec))

(defclass GENERIC-TIMESPEC (is-a USER)
  (slot sec (type INTEGER))
  (slot nsec (type INTEGER)))

; ----------------------------------------------------------------------
; Extra mq-send tests (descriptor types, capacity, msgsize, timespec types)
; ----------------------------------------------------------------------

(deffunction run-mq-send-extra-tests ()
  (bind ?name (format nil "/mq-send-extra-%s" (gensym*)))
  (bind ?q
        (mq-open ?name
                 (create$ O_CREAT O_EXCL O_RDWR O_NONBLOCK)
                 600
                 (create$ 0 1 16 0))) ; maxmsg=1, msgsize=16

  (expect "mq-send-extra: open queue returns integer"
          TRUE
          (integerp ?q))

  (if (not (integerp ?q))
   then
    (return))

  (bind ?other-fact
        (assert (other-template (foo 1))))

  (expect "mq-send-extra: descriptor wrong fact template fails"
          FALSE
          (mq-send ?q ?other-fact))

  (make-instance [other-inst] of OTHER-CLASS
    (foo 1))

  (expect "mq-send-extra: descriptor wrong instance class fails"
          FALSE
          (mq-send ?q (instance-address [other-inst])))

  ; fact missing slots
  (bind ?msg-fact-missing
        (assert (mq-message (data "missing-priority"))))
  (expect "mq-send-extra: fact missing priority slot uses default and succeeds"
          TRUE
          (mq-send ?q ?msg-fact-missing))

  ; queue capacity: second send should fail (maxmsg=1)
  (expect "mq-send-extra: second send on full queue fails"
          FALSE
          (mq-send ?q (create$ "second" 1)))

  ; receive to drain
  (bind ?m (mq-receive ?q))
  (expect "mq-send-extra: receive from capacity queue succeeds"
          TRUE
          (stringp ?m))

  ; message size tests
  (expect "mq-send-extra: data length == msgsize succeeds"
          TRUE
          (mq-send ?q (create$ "1234567890abcdef" 1)))

  (bind ?attr-after-eq (mq-getattr ?q))
  (expect "mq-send-extra: curmsgs==1 after exact-size send"
          TRUE
          (= (nth$ 4 ?attr-after-eq) 1))

  (bind ?m2 (mq-receive ?q))
  (expect "mq-send-extra: receive after exact-size send succeeds"
          TRUE
          (stringp ?m2))

  (expect "mq-send-extra: data length > msgsize fails (EMSGSIZE path)"
          FALSE
          (mq-send ?q (create$ "1234567890abcdefX" 1)))

  (bind ?ts-other-fact
        (assert (other-template (foo 1))))

  (expect "mq-send-extra: timespec fact template without expected slots succeeds"
          TRUE
          (mq-send ?q (create$ "ts-other-fact" 1) 7 ?ts-other-fact))

  (expect "mq-send-extra: receive from maxmsgs 1 queue"
  "ts-othe"
  (mq-receive ?q))

  (make-instance [ts-other-inst] of OTHER-CLASS
    (foo 1))

  (expect "mq-send-extra: timespec instance from defclass without expected slots succeeds"
          TRUE
          (mq-send ?q (create$ "ts-other-inst" 1) 7 (instance-address [ts-other-inst])))

  (expect "mq-send-extra: receive from maxmsgs 1 queue"
  "ts-othe"
  (mq-receive ?q))

  ; --------------------------------------------------------------------
  ; descriptor: fact/instance of any deftemplate/defclass with data/priority
  ; --------------------------------------------------------------------

  (bind ?custom-fact
        (assert (custom-mq-message (data "custom-fact")
                                   (priority 3))))

  (expect "mq-send-extra: fact descriptor with custom deftemplate succeeds"
          TRUE
          (mq-send ?q ?custom-fact))

  (bind ?m-custom-fact (mq-receive ?q multifield))
  (expect "mq-send-extra: receive after custom deftemplate fact send succeeds"
  MULTIFIELD
  (class ?m-custom-fact))

  (if (not (multifieldp ?m-custom-fact))
   then
    (return))

  (expect "mq-send-extra: multifield has 2 values"
  2
  (length$ ?m-custom-fact))

  (expect "mq-send-extra: multifield first value is data from sent fact"
  "custom-fact"
  (nth$ 1 ?m-custom-fact))

  (expect "mq-send-extra: multifield first value is priority from sent fact"
  3
  (nth$ 2 ?m-custom-fact))

  (make-instance [custom-inst] of CUSTOM-MQ-MESSAGE
    (data "custom-inst")
    (priority 4))

  (expect "mq-send-extra: instance descriptor with custom defclass succeeds"
          TRUE
          (mq-send ?q (instance-address [custom-inst])))

  (bind ?m-custom-inst (mq-receive ?q))
  (expect "mq-send-extra: receive after custom defclass instance send succeeds"
          "custom-inst"
          ?m-custom-inst)

  ; --------------------------------------------------------------------
  ; ParseTimespecFromValue: fact/instance of any deftemplate/defclass
  ; --------------------------------------------------------------------

  (bind ?ts-generic-fact
        (assert (generic-timespec (sec 2000000000)
                                  (nsec 0))))

  (expect "mq-send-extra: timespec from generic-timespec fact succeeds"
          TRUE
          (mq-send ?q (create$ "ts-generic-fact" 1) 7 ?ts-generic-fact))

  (bind ?m-ts-generic-fact (mq-receive ?q))
  (expect "mq-send-extra: receive after generic-timespec fact timespec send succeeds"
  "ts-gene"
  ?m-ts-generic-fact)

  (make-instance [ts-generic-inst] of GENERIC-TIMESPEC
    (sec 2000000000)
    (nsec 0))

  (expect "mq-send-extra: timespec from GENERIC-TIMESPEC instance succeeds"
          TRUE
          (mq-send ?q (create$ "ts-generic-inst" 1) 7 (instance-address [ts-generic-inst])))

  (bind ?m-ts-generic-inst (mq-receive ?q))
  (expect "mq-send-extra: receive after GENERIC-TIMESPEC instance timespec send succeeds"
  "ts-gene"
  ?m-ts-generic-inst)

  (mq-close ?q)
  (mq-unlink ?name)

  (printout t crlf))

; ----------------------------------------------------------------------
; Extra mq-open tests (invalid names, oflags, mq_attr shapes, reuse)
; ----------------------------------------------------------------------

(deffunction run-mq-open-extra-tests ()
  ; invalid names
  (expect "mq-open: name without leading slash fails"
          FALSE
          (mq-open "mq-no-slash"
                   (create$ O_CREAT O_EXCL O_RDWR)
                   600
                   (create$ 0 5 64 0)))

  (expect "mq-open: empty string name fails"
          FALSE
          (mq-open ""
                   (create$ O_CREAT O_EXCL O_RDWR)
                   600
                   (create$ 0 5 64 0)))

  ; oflag as empty multifield and bad single symbol
  (bind ?name-oflag-empty (format nil "/mq-oflag-empty-%s" (gensym*)))
  (expect "mq-open: oflag empty multifield fails"
          FALSE
          (mq-open ?name-oflag-empty
                   (create$)
                   600
                   (create$ 0 5 64 0)))

  (bind ?name-oflag-bad (format nil "/mq-oflag-bad-single-%s" (gensym*)))
  (expect "mq-open: oflag bad single symbol fails"
          FALSE
          (mq-open ?name-oflag-bad
                   BAD_FLAG
                   600
                   (create$ 0 5 64 0)))

  (bind ?bad-attr-fact
        (assert (other-template (foo 1))))

  (bind ?name-attr-wrong-fact (format nil "/mq-attr-wrong-fact-%s" (gensym*)))
  (expect "mq-open: mq_attr fact wrong template fails"
          FALSE
          (mq-open ?name-attr-wrong-fact
                   (create$ O_CREAT O_EXCL O_RDWR)
                   600
                   ?bad-attr-fact))

  (make-instance [mq-attr-wrong-inst] of OTHER-CLASS
    (foo 1))

  (bind ?name-attr-wrong-inst (format nil "/mq-attr-wrong-inst-%s" (gensym*)))
  (expect "mq-open: mq_attr instance wrong class fails"
          FALSE
          (mq-open ?name-attr-wrong-inst
                   (create$ O_CREAT O_EXCL O_RDWR)
                   600
                   (instance-address [mq-attr-wrong-inst])))

  ; reuse behavior: open same name twice without O_EXCL and share
  (bind ?name-reuse (format nil "/mq-open-reuse-%s" (gensym*)))
  (bind ?q1
        (mq-open ?name-reuse
                 (create$ O_CREAT O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-open-extra: first open for reuse returns integer"
          TRUE
          (integerp ?q1))

  (bind ?q2
        (mq-open ?name-reuse
                 (create$ O_RDWR)
                 600))

  (expect "mq-open-extra: second open without O_EXCL returns integer"
          TRUE
          (integerp ?q2))

  (if (and (integerp ?q1) (integerp ?q2))
   then
    (expect "mq-open-extra: send via q1 succeeds"
            TRUE
            (mq-send ?q1 (create$ "reuse-msg" 1)))
    (bind ?m (mq-receive ?q2))
    (expect "mq-open-extra: receive via q2 sees reuse-msg"
            TRUE
            (and
		    (stringp ?m)
		    (eq ?m "reuse-msg"))))

  (if (integerp ?q1)
   then
    (mq-close ?q1))

  (if (integerp ?q2)
   then
    (mq-close ?q2))

  (mq-unlink ?name-reuse)

  (printout t crlf))

; ----------------------------------------------------------------------
; Extra mq-getattr tests (rtype edge cases)
; ----------------------------------------------------------------------

(deffunction run-mq-getattr-extra-tests ()
  (bind ?name (format nil "/mq-getattr-extra-%s" (gensym*)))
  (bind ?q
        (mq-open ?name
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-getattr-extra: open queue returns integer"
          TRUE
          (integerp ?q))

  (if (not (integerp ?q))
   then
    (return))

  (bind ?attr-unknown (mq-getattr ?q unknown-rtype))

  (expect "mq-getattr-extra: unknown rtype falls back to multifield"
          TRUE
          (and (multifieldp ?attr-unknown)
               (= (length$ ?attr-unknown) 4)
               (integerp (nth$ 1 ?attr-unknown))
               (integerp (nth$ 2 ?attr-unknown))
               (integerp (nth$ 3 ?attr-unknown))
               (integerp (nth$ 4 ?attr-unknown))))

  (mq-close ?q)
  (mq-unlink ?name)

  (printout t crlf))

; ----------------------------------------------------------------------
; Extra mq-setattr tests (mq_attr shapes, rtype edge cases)
; ----------------------------------------------------------------------

(deffunction run-mq-setattr-extra-tests ()
  (bind ?name (format nil "/mq-setattr-extra-%s" (gensym*)))
  (bind ?q
        (mq-open ?name
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-setattr-extra: open queue returns integer"
          TRUE
          (integerp ?q))

  (if (not (integerp ?q))
   then
    (return))

  (bind ?orig (mq-getattr ?q))

  ; mq_attr bad fact shape (missing slots -> defaults are non-integer)
  (bind ?fact-missing
        (assert (mq-attr (flags 0)
                         (maxmsg 10)
                         (msgsize 64))))
  (expect "mq-setattr-extra: mq_attr fact with missing slot does not fail"
          ?orig
          (mq-setattr ?q ?fact-missing multifield))

  ; mq_attr bad instance shape (wrong declared type via OTHER-CLASS)
  (make-instance [mq-attr-other] of OTHER-CLASS
    (foo 1))

  (bind ?mq-setattr-extra-inst (mq-setattr ?q (instance-address [mq-attr-other]) multifield))

  (expect "mq-setattr-extra: mq_attr instance class without expected flags, maxmsg, msgsize, curmsgs still succeeds"
          MULTIFIELD
          (class ?mq-setattr-extra-inst))

  (if (not (multifieldp ?mq-setattr-extra-inst))
   then
    (return))


  (mq-close ?q)
  (mq-unlink ?name)

  (printout t crlf))

; ----------------------------------------------------------------------
; Extra mq-notify tests (repeat registration, bad sigevent types)
; ----------------------------------------------------------------------

(deffunction run-mq-notify-extra-tests ()
  ; repeat registration on same descriptor
  (bind ?name1 (format nil "/mq-notify-repeat-%s" (gensym*)))
  (bind ?q1
        (mq-open ?name1
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-notify-extra: open queue for repeat registration returns integer"
          TRUE
          (integerp ?q1))

  (if (integerp ?q1)
   then
    (expect "mq-notify-extra: first registration succeeds"
            TRUE
            (mq-notify ?q1))
    (expect "mq-notify-extra: second registration on same descriptor succeeds (replaces)"
            TRUE
            (mq-notify ?q1))
    (mq-close ?q1)
    (mq-unlink ?name1))

  ; bad sigevent types on fresh queue (no prior registration)
  (bind ?name2 (format nil "/mq-notify-bad-sigevent-%s" (gensym*)))
  (bind ?q2
        (mq-open ?name2
                 (create$ O_CREAT O_EXCL O_RDWR O_NONBLOCK)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-notify-extra: open queue for bad sigevent tests returns integer"
          TRUE
          (integerp ?q2))

  (if (not (integerp ?q2))
   then
    (return))

  (bind ?sev-missing
        (assert (mq-sigevent (notify 0)
                             (signo 10))))
  (expect "mq-notify-extra: sigevent fact missing value slot does not fail"
          TRUE
          (mq-notify ?q2 ?sev-missing))

  (expect "mq-notify-extra: un-notify"
  TRUE
  (mq-notify ?q2))

  (make-instance [sev-other] of OTHER-CLASS
    (foo 1))

  (expect "mq-notify-extra: sigevent instance missing value slot does not fail"
          TRUE
          (mq-notify ?q2 (instance-address [sev-other])))

  (expect "mq-notify-extra: returns FALSE if already mq-notify"
  FALSE
  (mq-notify ?q2 (create$ 0 10)))

  (mq-close ?q2)
  (mq-unlink ?name2)

  (printout t crlf))

; ----------------------------------------------------------------------
; Extra mq-receive tests (rtype edge cases, mode, buflen)
; ----------------------------------------------------------------------

(deffunction run-mq-receive-extra-tests ()
  (bind ?name-rtype (format nil "/mq-recv-rtype-%s" (gensym*)))
  (bind ?q-rtype
        (mq-open ?name-rtype
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-receive-extra: rtype queue open returns integer"
          TRUE
          (integerp ?q-rtype))

  (if (integerp ?q-rtype)
   then
    (mq-send ?q-rtype (create$ "r1" 1))
    (bind ?m-unknown (mq-receive ?q-rtype unknown-rtype))

    (expect "mq-receive-extra: unknown rtype is FALSE"
            FALSE
	    ?m-unknown)

    (mq-send ?q-rtype (create$ "r2" 1))
    (bind ?m-int-rtype (mq-receive ?q-rtype 42))

    (expect "mq-receive-extra: non-lexeme rtype is FALSE"
            FALSE
	    ?m-int-rtype)

    (mq-close ?q-rtype)
    (mq-unlink ?name-rtype))

  ; mode tests: O_WRONLY queue cannot receive
  (bind ?name-wr (format nil "/mq-recv-owronly-%s" (gensym*)))
  (bind ?q-wr
        (mq-open ?name-wr
                 (create$ O_CREAT O_EXCL O_WRONLY)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-receive-extra: O_WRONLY open returns integer"
          TRUE
          (integerp ?q-wr))

  (if (integerp ?q-wr)
   then
    (expect "mq-receive-extra: mq-receive on O_WRONLY queue fails"
            FALSE
            (mq-receive ?q-wr))
    (mq-close ?q-wr)
    (mq-unlink ?name-wr))

  ; O_RDONLY | O_NONBLOCK empty queue with rtype fact/instance
  (bind ?name-nb (format nil "/mq-recv-nonblock-%s" (gensym*)))
  (bind ?q-nb
        (mq-open ?name-nb
                 (create$ O_CREAT O_EXCL O_RDONLY O_NONBLOCK)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-receive-extra: nonblocking queue open returns integer"
          TRUE
          (integerp ?q-nb))

  (if (integerp ?q-nb)
   then
    (expect "mq-receive-extra: fact rtype on empty nonblocking queue fails"
            FALSE
            (mq-receive ?q-nb fact))
    (expect "mq-receive-extra: instance rtype on empty nonblocking queue fails"
            FALSE
            (mq-receive ?q-nb instance))
    (mq-close ?q-nb)
    (mq-unlink ?name-nb))

  ; buflen smaller than message length -> failure
  (bind ?name-len (format nil "/mq-recv-buflen-%s" (gensym*)))
  (bind ?q-len
        (mq-open ?name-len
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-receive-extra: buflen queue open returns integer"
          TRUE
          (integerp ?q-len))

  (if (integerp ?q-len)
   then
    (mq-send ?q-len (create$ "1234567890" 1)) ; len=10
    (expect "mq-receive-extra: buflen smaller than data length fails"
            FALSE
            (mq-receive ?q-len 5 multifield))
    (bind ?m-ok (mq-receive ?q-len 64 multifield))
    (expect "mq-receive-extra: receive with large buflen succeeds"
            TRUE
            (multifieldp ?m-ok))
    ; ------------------------------------------------------------------
    ; Now exercise every mq-receive signature, including those without
    ; an explicit buffer length.
    ; ------------------------------------------------------------------

    ; 1) fact rtype + buflen
    (mq-send ?q-len (create$ "len-fact" 2))
    (bind ?f-len (mq-receive ?q-len 64 fact))

    (expect "mq-receive-extra: fact rtype with buflen succeeds"
            TRUE
            (and (fact-addressp ?f-len)
                 (eq (fact-slot-value ?f-len data) "len-fact")
                 (integerp (fact-slot-value ?f-len priority))))

    ; 2) instance rtype + buflen
    (mq-send ?q-len (create$ "len-inst" 3))
    (bind ?i-len (mq-receive ?q-len 64 instance))

    (expect "mq-receive-extra: instance rtype with buflen succeeds"
            TRUE
            (and (instancep ?i-len)
                 (eq (send ?i-len get-data) "len-inst")
                 (integerp (send ?i-len get-priority))))

    ; 3) instance rtype + buflen + instance-name
    (mq-send ?q-len (create$ "len-inst-name" 4))
    (bind ?i-len-name (mq-receive ?q-len 64 instance len-inst-name))

    (expect "mq-receive-extra: instance rtype + name with buflen succeeds"
            TRUE
            (and (instancep ?i-len-name)
                 (eq (send ?i-len-name get-data) "len-inst-name")
                 (integerp (send ?i-len-name get-priority))))

    ; 4) instance rtype + instance-name (no buflen)
    (mq-send ?q-len (create$ "nolen-inst-name" 5))
    (bind ?i-nolen-name (mq-receive ?q-len instance nolen-inst-name))

    (expect "mq-receive-extra: instance rtype + name without buflen succeeds"
            TRUE
            (and (instancep ?i-nolen-name)
                 (eq (send ?i-nolen-name get-data) "nolen-inst-name")
                 (integerp (send ?i-nolen-name get-priority))))

    ; 5) fact rtype + deftemplate
    (mq-send ?q-len (create$ "nolen-fact" 5))
    (bind ?f-fact (mq-receive ?q-len fact))

    (expect "mq-receive-extra: fact rtype without buflen succeeds"
            TRUE
            (and
	    	 (eq mq-message (fact-relation ?f-fact))
	     	 (fact-existp ?f-fact)
                 (eq (fact-slot-value ?f-fact data) "nolen-fact")
                 (integerp (fact-slot-value ?f-fact priority))))

    ; 6) fact rtype + non existant deftemplate
    (mq-send ?q-len (create$ "nolen-non-existent-deftemplate-name" 5))
    (bind ?f-non-existent-deftemplate-name (mq-receive ?q-len fact my-template))

    (expect "mq-receive-extra: fact rtype + non existent deftemplate name without buflen succeeds"
            FALSE
	    ?f-non-existent-deftemplate-name)

    ; 7) fact rtype + deftemplate
    (bind ?f-deftemplate-name (mq-receive ?q-len fact custom-mq-message))

    (expect "mq-receive-extra: fact rtype + deftemplate name without buflen succeeds"
            TRUE
            (and
	    	 (eq custom-mq-message (fact-relation ?f-deftemplate-name))
		 (fact-existp ?f-deftemplate-name)
                 (eq (fact-slot-value ?f-deftemplate-name data) "nolen-non-existent-deftemplate-name")
                 (integerp (fact-slot-value ?f-deftemplate-name priority))))

    ; 8) string rtype
    (mq-send ?q-len (create$ "string!" 5))
    (bind ?f-string (mq-receive ?q-len string foo))

    (expect "mq-receive-extra: nothing allowed beyond string"
            FALSE
	    ?f-string)

    (bind ?f-string (mq-receive ?q-len string))

    (expect "mq-receive-extra: string without buflen succeeds"
            "string!"
	    ?f-string)

    (mq-close ?q-len)
    (mq-unlink ?name-len))

  (printout t crlf))

; ----------------------------------------------------------------------
; Cross-descriptor tests (send on one descriptor, receive on another)
; ----------------------------------------------------------------------

(deffunction run-mq-cross-descriptor-tests ()
  (bind ?name (format nil "/mq-cross-desc-%s" (gensym*)))

  (bind ?q1
        (mq-open ?name
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (bind ?q2
        (mq-open ?name
                 (create$ O_RDWR)
                 600))

  (expect "mq-cross-desc: q1 open returns integer"
          TRUE
          (integerp ?q1))

  (expect "mq-cross-desc: q2 open returns integer"
          TRUE
          (integerp ?q2))

  (if (and (integerp ?q1) (integerp ?q2))
   then
    (expect "mq-cross-desc: send via q1"
            TRUE
            (mq-send ?q1 (create$ "xdesc-mf" 1)))
    (bind ?m-multi (mq-receive ?q2 multifield))
    (expect "mq-cross-desc: receive via q2 (multifield)"
            TRUE
            (and (multifieldp ?m-multi)
                 (= (length$ ?m-multi) 2)
                 (eq (nth$ 1 ?m-multi) "xdesc-mf")
                 (integerp (nth$ 2 ?m-multi))))

    (expect "mq-cross-desc: send via q1 for fact rtype"
            TRUE
            (mq-send ?q1 (create$ "xdesc-fact" 2)))
    (bind ?f (mq-receive ?q2 fact))
    (expect "mq-cross-desc: receive via q2 (fact)"
            TRUE
            (and (fact-addressp ?f)
                 (eq (fact-slot-value ?f data) "xdesc-fact")
                 (integerp (fact-slot-value ?f priority))))

    (expect "mq-cross-desc: send via q1 for instance rtype"
            TRUE
            (mq-send ?q1 (create$ "xdesc-inst" 3)))
    (bind ?i (mq-receive ?q2 instance))
    (expect "mq-cross-desc: receive via q2 (instance)"
            TRUE
            (and (instancep ?i)
                 (eq (send ?i get-data) "xdesc-inst")
                 (integerp (send ?i get-priority)))))

  (if (integerp ?q1) then (mq-close ?q1))
  (if (integerp ?q2) then (mq-close ?q2))
  (mq-unlink ?name)

  (printout t crlf))

; ----------------------------------------------------------------------
; Stress-ish loop test (send/receive many messages)
; ----------------------------------------------------------------------

(deffunction run-mq-stress-tests ()
  (bind ?name (format nil "/mq-stress-%s" (gensym*)))
  (bind ?q
        (mq-open ?name
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 10 64 0)))

  (expect "mq-stress: open queue returns integer"
          TRUE
          (integerp ?q))

  (if (not (integerp ?q))
   then
    (return))

  (bind ?ok TRUE)

  (loop-for-count (?i 1 50)
    (if (not (mq-send ?q (create$ "stress-msg" 1)))
     then
      (bind ?ok FALSE))
    (bind ?m (mq-receive ?q))
    (if (not (and (stringp ?m)
                  (eq ?m "stress-msg")))
     then
      (bind ?ok FALSE)))

  (expect "mq-stress: 50 send/receive iterations all succeeded"
          TRUE
          ?ok)

  (bind ?attr (mq-getattr ?q))

  (expect "mq-stress: queue empty after loop"
          TRUE
          (= (nth$ 4 ?attr) 0))

  (mq-close ?q)
  (mq-unlink ?name)

  (printout t crlf))

  ; ----------------------------------------------------------------------
; Structures for timespec via facts and instances (clock-gettime)
; ----------------------------------------------------------------------

(deftemplate my-timespec-template
  (slot sec)
  (slot nsec))

(defclass MY-TIMESPEC-CLASS (is-a USER)
  (slot sec (type INTEGER))
  (slot nsec (type INTEGER)))

; ----------------------------------------------------------------------
; Test driver for clock-gettime
; ----------------------------------------------------------------------

(deffunction run-clock-gettime-tests ()
  ; baseline: (clock-gettime)
  (bind ?t0 (clock-gettime))

  (expect "clock-gettime: () returns multifield"
          TRUE
          (and (multifieldp ?t0)
               (= (length$ ?t0) 2)
               (integerp (nth$ 1 ?t0))
               (integerp (nth$ 2 ?t0))
               (>= (nth$ 1 ?t0) 0)
               (>= (nth$ 2 ?t0) 0)
               (<  (nth$ 2 ?t0) 1000000000)))

  ; (clock-gettime CLOCK_REALTIME)
  (bind ?t1 (clock-gettime CLOCK_REALTIME))

  (expect "clock-gettime: (CLOCK_REALTIME) returns multifield"
          TRUE
          (and (multifieldp ?t1)
               (= (length$ ?t1) 2)
               (integerp (nth$ 1 ?t1))
               (integerp (nth$ 2 ?t1))
               (>= (nth$ 1 ?t1) 0)
               (>= (nth$ 2 ?t1) 0)
               (<  (nth$ 2 ?t1) 1000000000)))

  ; (clock-gettime CLOCK_REALTIME (create$ 60 0))
  (bind ?t60a (clock-gettime CLOCK_REALTIME (create$ 60 0)))

  (expect "clock-gettime: (CLOCK_REALTIME (60 0)) returns multifield"
          TRUE
          (and (multifieldp ?t60a)
               (= (length$ ?t60a) 2)
               (integerp (nth$ 1 ?t60a))
               (integerp (nth$ 2 ?t60a))
               (<  (nth$ 2 ?t60a) 1000000000)))

  (expect "clock-gettime: (CLOCK_REALTIME (60 0)) sec advanced"
          TRUE
          (>= (nth$ 1 ?t60a) (+ (nth$ 1 ?t1) 59)))

  ; (clock-gettime (create$ 60 0))
  (bind ?t60b (clock-gettime (create$ 60 0)))

  (expect "clock-gettime: ((60 0)) returns multifield"
          TRUE
          (and (multifieldp ?t60b)
               (= (length$ ?t60b) 2)
               (integerp (nth$ 1 ?t60b))
               (integerp (nth$ 2 ?t60b))
               (<  (nth$ 2 ?t60b) 1000000000)))

  (expect "clock-gettime: ((60 0)) sec advanced"
          TRUE
          (>= (nth$ 1 ?t60b) (+ (nth$ 1 ?t0) 59)))

  ; (clock-gettime (create$ 60 0) multifield)
  (bind ?t60c (clock-gettime (create$ 60 0) multifield))

  (expect "clock-gettime: ((60 0) multifield) returns multifield"
          TRUE
          (and (multifieldp ?t60c)
               (= (length$ ?t60c) 2)
               (integerp (nth$ 1 ?t60c))
               (integerp (nth$ 2 ?t60c))
               (<  (nth$ 2 ?t60c) 1000000000)))

  (expect "clock-gettime: ((60 0) multifield) sec advanced"
          TRUE
          (>= (nth$ 1 ?t60c) (+ (nth$ 1 ?t0) 59)))

  ; (clock-gettime fact my-timespec-template)
  (bind ?tf0 (clock-gettime fact my-timespec-template))

  (expect "clock-gettime: (fact my-timespec-template) returns fact"
          TRUE
          (and (fact-addressp ?tf0)
               (eq my-timespec-template (fact-relation ?tf0))
               (integerp (fact-slot-value ?tf0 sec))
               (integerp (fact-slot-value ?tf0 nsec))
               (>= (fact-slot-value ?tf0 sec) 0)
               (>= (fact-slot-value ?tf0 nsec) 0)
               (<  (fact-slot-value ?tf0 nsec) 1000000000)))

  ; (clock-gettime CLOCK_REALTIME (create$ 60 0) multifield)
  (bind ?t60d (clock-gettime CLOCK_REALTIME (create$ 60 0) multifield))

  (expect "clock-gettime: (CLOCK_REALTIME (60 0) multifield) returns multifield"
          TRUE
          (and (multifieldp ?t60d)
               (= (length$ ?t60d) 2)
               (integerp (nth$ 1 ?t60d))
               (integerp (nth$ 2 ?t60d))
               (<  (nth$ 2 ?t60d) 1000000000)))

  (expect "clock-gettime: (CLOCK_REALTIME (60 0) multifield) sec advanced"
          TRUE
          (>= (nth$ 1 ?t60d) (+ (nth$ 1 ?t1) 59)))

  ; (clock-gettime CLOCK_REALTIME (create$ 60 0) fact my-timespec-template)
  (bind ?tf60 (clock-gettime CLOCK_REALTIME (create$ 60 0) fact my-timespec-template))

  (expect "clock-gettime: (CLOCK_REALTIME (60 0) fact my-timespec-template) returns fact"
          TRUE
          (and (fact-addressp ?tf60)
               (eq my-timespec-template (fact-relation ?tf60))
               (integerp (fact-slot-value ?tf60 sec))
               (integerp (fact-slot-value ?tf60 nsec))
               (<  (fact-slot-value ?tf60 nsec) 1000000000)))

  (expect "clock-gettime: (CLOCK_REALTIME (60 0) fact ...) sec advanced"
          TRUE
          (>= (fact-slot-value ?tf60 sec) (+ (nth$ 1 ?t1) 59)))

  (clock-gettime CLOCK_REALTIME (create$ 60 0) instance MY-TIMESPEC-CLASS myTimespecInstanceName)
  (if (not (instance-existp [myTimespecInstanceName]))
   then
    (make-instance [myTimespecInstanceName] of MY-TIMESPEC-CLASS
      (sec 0)
      (nsec 0)))

  (bind ?ti60 (clock-gettime CLOCK_REALTIME (create$ 60 0) instance MY-TIMESPEC-CLASS myOtherTimespecInstanceName))

  (expect "clock-gettime: (CLOCK_REALTIME (60 0) instance MY-TIMESPEC-CLASS myOtherTimespecInstanceName) returns instance"
          TRUE
          (and (instancep ?ti60)
               (eq MY-TIMESPEC-CLASS (class ?ti60))
               (integerp (send ?ti60 get-sec))
               (integerp (send ?ti60 get-nsec))
               (>= (send ?ti60 get-sec) 0)
               (>= (send ?ti60 get-nsec) 0)
               (<  (send ?ti60 get-nsec) 1000000000)))

  (expect "clock-gettime: (CLOCK_REALTIME (60 0) instance ...) sec advanced"
          TRUE
          (>= (send ?ti60 get-sec) (+ (nth$ 1 ?t1) 59)))

  ; ---------------- clock-gettime error paths ----------------

  (expect "clock-gettime: invalid clockid symbol fails"
          FALSE
          (clock-gettime BAD_CLOCK))

  (expect "clock-gettime: timespec multifield too short fails"
          FALSE
          (clock-gettime CLOCK_REALTIME (create$ 60)))

  (expect "clock-gettime: timespec multifield contains non-integer fails"
          FALSE
          (clock-gettime CLOCK_REALTIME (create$ "sec" 0)))

  (expect "clock-gettime: timespec multifield nsec out of range fails"
          FALSE
          (clock-gettime CLOCK_REALTIME (create$ 0 1000000000)))

  (bind ?other-fact (assert (other-template (foo 1))))
  (bind ?clock-realtime-mf (clock-gettime CLOCK_REALTIME ?other-fact))

  (expect "clock-gettime: timespec fact template without sec or nsec still succeeds"
          MULTIFIELD
          (class ?clock-realtime-mf))

  (if (not (multifieldp ?clock-realtime-mf))
   then
    (return))

  (expect "clock-gettime: timespec fact template without sec or nsec has 2 values"
          2
          (length$ ?clock-realtime-mf))

  (expect "clock-gettime: timespec fact template without sec or nsec first value is integer"
          INTEGER
          (class (nth$ 1 ?clock-realtime-mf)))

  (expect "clock-gettime: timespec fact template without sec or nsec second value is integer"
          INTEGER
          (class (nth$ 2 ?clock-realtime-mf)))

  (make-instance [other-ts-inst] of OTHER-CLASS
    (foo 1))
  
  (bind ?clock-realtime-inst (clock-gettime CLOCK_REALTIME (instance-address [other-ts-inst])))

  (expect "clock-gettime: timespec instance class without sec or nsec slots still succeeds"
          MULTIFIELD
          (class ?clock-realtime-inst))

  (if (not (instancep ?clock-realtime-inst))
   then
    (return))

  (expect "clock-gettime: timespec instance defclass without sec or nsec has 2 values"
          2
          (length$ ?clock-realtime-inst))

  (expect "clock-gettime: timespec instance defclass without sec or nsec first value is integer"
          INTEGER
          (class (nth$ 1 ?clock-realtime-inst)))

  (expect "clock-gettime: timespec instance defclass without sec or nsec second value is integer"
          INTEGER
          (class (nth$ 2 ?clock-realtime-inst)))

  (expect "clock-gettime: string rtype rejects extra args"
          FALSE
          (clock-gettime CLOCK_REALTIME (create$ 60 0) string extra))

  (printout t crlf))


  (defclass MY-MQ-MSG (is-a USER)
    (slot data (type LEXEME))
    (slot priority (type INTEGER)))

  (deffunction run-mq-receive-instance-arg5-regression ()
  (bind ?qname (format nil "/mq-recv-inst-arg5-%s" (gensym*)))
  (bind ?q (mq-open ?qname (create$ O_CREAT O_EXCL O_RDWR) 600 (create$ 0 4 64 0)))
  (expect "mq-recv-inst-arg5: open returns integer" TRUE (integerp ?q))
  (if (not (integerp ?q)) then (return))

  (expect "mq-recv-inst-arg5: send succeeds"
          TRUE
          (mq-send ?q (create$ "hello" 7)))

  (bind ?ts (create$ 2000000000 0))
  (bind ?ins (mq-receive ?q 64 ?ts instance MY-MQ-MSG myInstanceName))

  (expect "mq-recv-inst-arg5: returns instance"
          TRUE
          (instancep ?ins))

  ; if bug exists (a4 used when handling a5), name will come back as MY-MQ-MSG
  (expect "mq-recv-inst-arg5: instance class respected"
          TRUE
          (eq (class ?ins) MY-MQ-MSG))

  (expect "mq-recv_inst-arg5: instance name respected"
          TRUE
          (or (eq (instance-name ?ins) myInstanceName)
              (eq (instance-name ?ins) [myInstanceName])))

  (refute "mq-recv-inst-arg5: instance name must NOT equal class symbol"
          MY-MQ-MSG
          (instance-name ?ins))

  (mq-close ?q)
  (mq-unlink ?qname)
)

; ----------------------------------------------------------------------
; Regression: mq-send must actually use mq_timedsend when a timespec is provided
; Bug: ts computed but timeoutPtr never set => timed send dead code
;
; Expectation:
;   - past absolute timeout => FALSE (ETIMEDOUT path) if mq_timedsend is used
;   - future absolute timeout => TRUE
; If your current code ignores timeoutPtr, BOTH will behave like plain mq_send
; and the "past" case will incorrectly succeed (this test will catch it).
; ----------------------------------------------------------------------

(deffunction run-mq-send-timespec-deadcode-regression ()
  (bind ?name (format nil "/mq-send-ts-deadcode-%s" (gensym*)))
  (bind ?q
        (mq-open ?name
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 1 64 0)))

  (expect "mq-send-ts-deadcode: open returns integer"
          TRUE
          (integerp ?q))

  (if (not (integerp ?q)) then (return))

  (bind ?ts-future (create$ 2000000000 0))
  (expect "mq-send-ts-deadcode: mq-send with future timespec should SUCCEED"
          TRUE
          (mq-send ?q (create$ "should-send" 2) 2 ?ts-future))

  (bind ?ts-past (create$ 0 0))
  (expect "mq-send-ts-deadcode: mq-send with past timespec should FAIL"
          FALSE
          (mq-send ?q (create$ "should-timeout" 1) 1 ?ts-past))

  (bind ?m (mq-receive ?q multifield))
  (expect "mq-send-ts-deadcode: receive after future timed send"
          TRUE
          (and (multifieldp ?m)
               (= (length$ ?m) 2)
               (eq (nth$ 1 ?m) "sh")
               (integerp (nth$ 2 ?m))))

  (mq-close ?q)
  (mq-unlink ?name)
  (printout t crlf)
)

; ----------------------------------------------------------------------
; Regression: mq-getattr/mq-setattr should behave differently when the
; 3rd/4th args are interpreted as (rtype=instance, className) vs
; mistakenly as (rtype=instance, templateName).
;
; We can't capture stderr text in CLIPS without router APIs (not available),
; so we assert *semantic* behavior that depends on correct "class" parsing.
;
; These will FAIL if the implementation incorrectly looks for a deftemplate
; name in the "instance" branch (or otherwise confuses class/template).
; ----------------------------------------------------------------------

(defclass MQ-ATTR-CLASS-A (is-a USER)
  (slot flags (type INTEGER))
  (slot maxmsg (type INTEGER))
  (slot msgsize (type INTEGER))
  (slot curmsgs (type INTEGER)))

(deftemplate mq-attr-template-a
  (slot flags)
  (slot maxmsg)
  (slot msgsize)
  (slot curmsgs))

(deffunction run-mq-attr-class-vs-template-regressions ()
  (bind ?name (format nil "/mq-attr-class-vs-template-%s" (gensym*)))
  (bind ?q
        (mq-open ?name
                 (create$ O_CREAT O_EXCL O_RDWR)
                 600
                 (create$ 0 5 64 0)))

  (expect "mq-attr-reg: open returns integer"
          TRUE
          (integerp ?q))

  (if (not (integerp ?q)) then (return))

  ; ---- mq-getattr: instance + valid CLASS should return instance of that class ----
(bind ?gi (mq-getattr ?q instance MQ-ATTR-CLASS-A))
(expect "mq-getattr-reg: instance + class returns instance" TRUE (instancep ?gi))
(expect "mq-getattr-reg: instance is MQ-ATTR-CLASS-A" TRUE (eq (class ?gi) MQ-ATTR-CLASS-A))

; ---- mq-getattr: instance + TEMPLATE name must not be accepted as a class ----
(bind ?gi2 (mq-getattr ?q instance mq-attr-template-a))
(expect "mq-getattr-reg: instance + template-name should FAIL" FALSE ?gi2)

; ---- mq-setattr: instance + valid CLASS should return instance of that class ----
(bind ?si (mq-setattr ?q (create$ 0 5 64 0) instance MQ-ATTR-CLASS-A))
(expect "mq-setattr-reg: instance + class returns instance" TRUE (instancep ?si))
(expect "mq-setattr-reg: instance is MQ-ATTR-CLASS-A" TRUE (eq (class ?si) MQ-ATTR-CLASS-A))

  (mq-close ?q)
  (mq-unlink ?name)
  (printout t crlf)
)


(run-errno-tests)
(run-mq-send-timespec-deadcode-regression)
(run-mq-attr-class-vs-template-regressions)
(run-mq-receive-instance-arg5-regression)
(run-clock-gettime-tests)
(run-mq-getattr-tests)
(run-mq-setattr-tests)
(run-mq-open-tests)
(run-mq-send-receive-tests)
(run-mq-multi-queue-timedreceive-tests)

(run-mq-open-extra-tests)
(run-mq-getattr-extra-tests)
(run-mq-setattr-extra-tests)
(run-mq-notify-extra-tests)
(run-mq-send-extra-tests)
(run-mq-receive-extra-tests)
(run-mq-cross-descriptor-tests)
(run-mq-stress-tests)

(mq-test-summary)
(exit)
