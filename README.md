# CLIPSmqueue

A CLIPS library for working with
POSIX Message Queues (known as "mqueue")

## Overview

This module exposes POSIX mqueue operations
(`mq_open`, `mq_close`, `mq_unlink`, `mq_getattr`,
`mq_setattr`, `mq_send`, `mq_timedsend`, `mq_receive`,
`mq_timedreceive`, and `mq_notify`)
as **CLIPS user-defined functions (UDFs)**
that you can use in your CLIPS rule engines.

The API supports sending and receiving queue messages
as `STRING`s, `SYMBOL`s, `MULTIFIELD`s, `FACT`s, and `INSTANCE`s.

## Building

Build the project by simply doing:

```
make
```

This will download the CLIPS `tar` from sourceforge,
extract the source code, copy the
`userfunctions.c` file in this repo,
then compile clips to the file `./vendor/clips/clips`.
This executable `clips` now has the functions available
as described in the [API](#API) section of this `README.md`.

You may also use this executable to run the programs
in the `examples` directory like this:

```
./clips/examples/1.bat
```

Finally, you can run the test suite by doing:

```
make test
```

## Examples

### Self-contained

Running this rules engine will count up to `5` using a single mqueue:

```
$ ./vendor/clips/clips -f2 examples/1.bat 
Msg: 1
Msg: 2
Msg: 3
Msg: 4
Msg: 5
Done!
         CLIPS (6.4.2 1/14/25)
CLIPS> (facts)
f-21    (queue 4 5)
f-23    (has-message TRUE)
For a total of 2 facts.
```

### "Send" and "Receive" rules engines

```
$ ./vendor/clips/clips -f2 examples/2.bat 
Created /foo mqueue...
Sent message to /foo mqueue...
Closed file descriptor for mqueue /foo...
Done! Now run ./vendor/clips/clips -f2 example/3.bat to receive your message!
$ ./vendor/clips/clips -f2 examples/3.bat 
Opened existing mqueue on disk /foo...
Got hi from 2.bat!
Deleted mqueue file on disk...
Closed file descriptor for mqueue /foo...
Done!
```

### Long-running "Send" and "Receive" rules engines

In one terminal:

```
$ ./vendor/clips/clips -f2 examples/4.bat
Created /foo mqueue...
```

In another terminal:

```
$ ./vendor/clips/clips -f2 examples/5.bat
Opened mqueue on disk /foo...
msg: 1
msg: 2
msg: 3
msg: 4
msg: 5
# ...
sg: 999996
msg: 999997
msg: 999998
msg: 999999
msg: 1000000
mq-receive: mq-receive: mq_timedreceive failed: Connection timed out
Closed file descriptor for mqueue /foo...
Deleting /foo...
Done!
```

You'll see this in the other terminal:

```
Sent messages to /foo mqueue...
Closed file descriptor for mqueue /foo...
Done! Now run ./vendor/clips/clips -f2 example/5.bat to receive your messages!
```

### Rainbow Colors, Uppercase, and Reverse

This example involves 3 separate files: 1 publishes the colors of a rainbow
to an mqueue, the other 2 pull messages from the queue, do some work
to the color names, and then publish them back onto another queue.
The first publisher then reads the updated words from the second queue.

First, run the publisher in one terminal:

```
$ ./vendor/clips/clips -f2 examples/6.bat
```

This will exit after 10 seconds. Within those 10 seconds, run one of the clients:

```
$ ./vendor/clips/clips -f2 examples/7.bat
```

You will begin to see some text output to the first terminal:

```
color from receive queue: 7:RED
color from receive queue: 7:ORANGE
color from receive queue: 7:YELLOW
color from receive queue: 7:GREEN
color from receive queue: 7:BLUE
color from receive queue: 7:INDIGO
color from receive queue: 7:VIOLET
```

While this is running, run this in a third terminal:

```
$ ./vendor/clips/clips -f2 examples/8.bat
```

You will now see the result of this second client modified text
in the first terminal alone with the second terminal's
modified text:

```
color from receive queue: 7:RED
color from receive queue: 8:egnaro
color from receive queue: 7:YELLOW
color from receive queue: 8:neerg
color from receive queue: 7:BLUE
color from receive queue: 8:ogidni
color from receive queue: 7:VIOLET
color from receive queue: 8:der
color from receive queue: 7:ORANGE
color from receive queue: 8:wolley
color from receive queue: 7:GREEN
color from receive queue: 8:eulb
color from receive queue: 7:INDIGO
color from receive queue: 8:teloiv
```

Close both of the clients, you'll see the first terminal
pause for 10 seconds before exiting:

```
color from receive queue: 7:GREEN
color from receive queue: 7:BLUE
color from receive queue: 7:INDIGO
color from receive queue: 7:VIOLET
mq-receive: mq-receive: mq_timedreceive failed: Connection timed out
Received timed out. bye bye!
         CLIPS (6.4.2 1/14/25)
CLIPS> 
```

## API

### `mq-open`

Creates a new POSIX message queue or opens an existing queue.

#### Signature  

```
(mq-open <name> <oflag> [<mode>] [<mq_attr>])
```

#### Arguments  

| Argument | Type | Description |
|---------|-------|-------------|
| `name` | `SYMBOL`/`STRING` | Message queue name (must begin with "/") |
| `oflag` | `SYMBOL`, `INTEGER`, or `MULTIFIELD` of `SYMBOL`s | specifies flags that control the operation of the call |
| `mode` (Optional) | `INTEGER`, `SYMBOL`, or `MULTIFIELD` | Required only when `oflag` argument `O_CREAT` is used |
| `mq_attr` | `MULTIFIELD`, `FACT`, or `INSTANCE` | Must contain: `flags`, `maxmsg`, `msgsize`, `curmsgs` |

Possible `oflag`s:

- `O_RDONLY`
- `O_WRONLY`
- `O_RDWR`
- `O_NONBLOCK`
- `O_CREAT`
- `O_EXCL`
- `O_TRUNC`

`mode` can either be an `INTEGER` representing the file mode bits
or the `SYMBOL`s:

- `S_IRUSR`
- `S_IWUSR`
- `S_IXUSR`
- `S_IRGRP`
- `S_IWGRP`
- `S_IXGRP`
- `S_IROTH`
- `S_IWOTH`
- `S_IXOTH`
- `S_IRWXU`
- `S_IRWXG`
- `S_IRWXO`

#### Return  

- `INTEGER`: An mqueue descriptor (`mqd_t`)
- `FALSE` on failure

---

### `mq-close`

Closes the process's handle to the message queue on disk.

#### Signature

```
(mq-close <mqd>)
```

#### Return

`TRUE` or `FALSE`

#### Notes

- Closing twice returns `FALSE`.

---

### `mq-unlink`

Deletes the mqueue file on disk.

#### Signature

```
(mq-unlink <name>)
```

#### Return

`TRUE` or `FALSE`

---

### `mq-getattr`

Retrieve attributes of a message queue

#### Signature

```
(mq-getattr <mqd> [rtype] [deftemplate | defclass])
```

#### rtype values

- `multifield` (default)
- `fact`
- `instance`

#### Return (rtype = multifield)

```
(<flags> <maxmsg> <msgsize> <curmsgs>)
```

#### Return (rtype = fact)

Fact of deftemplate specified in third argument.
Deftemplate must have slots `flags`, `maxmsg`, `msgsize`, and `curmsgs`.

#### Return (rtype = instance)

Instance of defclass specified in third argument
Defclass must have slots `flags`, `maxmsg`, `msgsize`, and `curmsgs`.

---

### `mq-setattr`

Modify attributes of a message queue

#### Signature

```
(mq-setattr <mqd> <mq_attr> [rtype] [deftemplate | defclass])
```

#### `mq_attr`

- `MULTIFIELD` of `INTEGER`s of the form `(<flags> <maxmsg> <msgsize> <curmsgs>)`
- `FACT` of Deftemplate with slots `flags`, `maxmsg`, `msgsize`, and `curmsgs`
- `INSTANCE` of Defclass with slots `flags`, `maxmsg`, `msgsize`, and `curmsgs`

#### `rtype`

- `multifield` (default)
- `fact`
- `instance`

#### `deftemplate` | `defclass`

This may be optionally specified if `rtype` is `fact` or `instance`.
The specified Deftemplate or Defclass must have the slots
`flags`, `maxmsg`, `msgsize`, and `curmsgs`.

#### Return

The old attributes format specified by `rtype`:

- `MULTIFIELD` of `INTEGER`s of the form `(<flags> <maxmsg> <msgsize> <curmsgs>)`
- `FACT` of Deftemplate specified by fourth argument (default `mq-attr`)
- `INSTANCE` of Defclass specified by fourth argument (default `MQ-ATTR`)

---

### `mq-notify`

Allows the calling process
to register or unregister for delivery
of an asynchronous notification
when a new message arrives on the empty message queue.
Only one process can be registered
to receive notification from a message queue.

#### Signature

```
(mq-notify <mqd> [sigevent])
```

#### `sigevent` formats

- `MULTIFIELD`: `(notify signo value)`
- `FACT` of Deftemplate with slots `notify`, `signo`, and `value`
- `INSTANCE` of Defclass with slots `notify`, `signo`, and `value`

#### Return

`TRUE` or `FALSE`

---

### `mq-send`

#### Signature

```
(mq-send <mqd> <descriptor> [len] [timespec])
```

#### Arguments

- `mqd`: Mqueue descriptor as an `INTEGER`
- `descriptor`: A `STRING`, `SYMBOL`, `MULTIFIELD`, `FACT`, or `INSTANCE`
- `len` (Optional): An `INTEGER` specifying the length of the message to send
- `timespec` (Optional): A `MULTIFIELD, `FACT`, or `INSTANCE`

#### `descriptor` formats

- `STRING` or `SYMBOL`: The data of the message using a priority of `0`
- `MULTIFIELD`: The message represented as `("data" [priority])`
- `FACT` of Deftemplate with slots `data` and `priority`
- `INSTANCE` of Defclass with slots `data` and `priority`

#### `timespec`

The **absolute** POSIX time to schedule this `mq_send`.
Use `clock-gettime` to get the current time
plus an optional offset. Valid formats are:

- `MULTIFIELD`: The timespec represented as `(sec nsec)`
- `FACT` of Deftemplate with slots `sec` and `nsec`
- `INSTANCE` of Defclass with slots `sec` and `nsec`

#### Behavior  

- message data must be string/symbol
- default priority = 0
- default length = strlen(data)
- when timespec provided, `mq_timedsend` used  

#### Return  

`TRUE` or `FALSE`

#### Notes

- Any of the arguments may be used after `<descriptor>`, but they must be specified in the order above
  - `(mq-send <mqd> "foo" 7)`
  - `(mq-send <mqd> "foo" 7 (create$ 100 0))`
  - `(mq-send <mqd> "foo" (create$ 100 0))`

---

### `mq-receive`

Receives a message currently on an mqueue.

#### Signature  

```
(mq-receive <mqd> [buflen] [timespec] [rtype] [deftemplate-name | (defclass-name [instance-name])])
```

#### Arguments
- `buflen`: An `INTEGER` specifying to buffer length to use to retrieve the message. Default to the full length of the message queued.
- `timespec` (Optional): A `MULTIFIELD, `FACT`, or `INSTANCE` specifying the absolute POST time to block until
  - Specifying this as an argument will use `mq_timedreceive` under the hood
- `rtype`: The type to return for the message. Possible values are:
  - `string` (default)
  - `symbol`
  - `multifield`
  - `fact`
  - `instance`
- `deftemplate-name`: may be used to specify the deftemplate of the fact to return if `rtype` is `fact`
- `defclass-name`: may be used to specify the defclass of the instance to return if `rtype` is `instance`
- `instance-name`: may be used to specify the name of the instance to return if `rtype` is `instance`


#### Return formats  

| rtype | Format |
|--------|---------|
| `string` (default) | `STRING` |
| `symbol` | `SYMBOL` |
| `multifield` | `("data" priority)` |
| `fact` | `FACT`, default to `mq-message` if a `deftemplate-name` is not specified |
| `instance` | `INSTANCE`, default to `MQ-MESSAGE` if a `defclass-name` is not specified |

#### Notes  

- Any of the arguments may be used after `<mqd>`, but they must be specified in the order above
  - `(mq-receive <mqd> 23 multifield)`
  - `(mq-receive <mqd> fact my-template)`
  - `(mq-receive <mqd> (create 23 56))`
  - `(mq-receive <mqd> (create 78 12) instance MY-DEFCLASS)`
- `timespec` should specify the **absolute** POSIX time to schedule this `mq_send`.
  Use `clock-gettime` to get the current time plus an optional offset.


---

### `clock-gettime`

Returns the current time from a POSIX clock with optional offset.
Use this to return a `timespec` argument for `mq-send` and `mq-receive`

#### Signature

```
(clock-gettime [clock-id] [offset] [rtype] [deftemplate-name | (defclass-name [instance-name])])
```

#### `clock-id` values

- `CLOCK_REALTIME` (default)
- `CLOCK_MONOTONIC`
- `CLOCK_PROCESS_CPUTIME_ID`
- `CLOCK_THREAD_CPUTIME_ID`
- `CLOCK_MONOTONIC_RAW`
- `CLOCK_REALTIME_COARSE`
- `CLOCK_MONOTONIC_COARSE`
- `CLOCK_BOOTTIME`
- `CLOCK_TAI`

#### `offset` formats  

- `MULTIFIELD`: The timespec represented as `(sec nsec)`
- `FACT` of Deftemplate with slots `sec` and `nsec`
- `INSTANCE` of Defclass with slots `sec` and `nsec`

#### Return formats  

| rtype | Format |
|--------|---------|
| `multifield` | `(sec nsec)` |
| `fact` | `FACT`, default to `timespec` if a `deftemplate-name` is not specified |
| `instance` | `INSTANCE`, default to `TIMESPEC` if a `defclass-name` is not specified |

#### Examples

```
(clock-gettime)
(clock-gettime CLOCK_REALTIME)
(clock-gettime (create$ 60 0))
(clock-gettime fact)
```

---

### `errno`

Returns `errno` upon error of functions in this library.
Returns `FALSE` when no `errno`.
