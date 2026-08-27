# The timeout path

How a timed-out test-run ends, and why it is shaped this way.

## What happens

`daemon_run.rb` runs cyber-dojo.sh in a container over the daemon socket, and
what bounds the run is the reading of the attach stream. There is no child
process to wait on, so timing out is neither a `Thread#join` answering `nil`
nor a `Timeout` firing.

`read_payload` takes an absolute deadline of `max_seconds` from the moment the
container has everything it needs, and `DeadlineReader` reapplies what is left
of it before every read. A read with nothing left, or a socket whose own
`IO#timeout=` runs out, raises `DeadlineReader::Expired`. `runner.rb` caps
`max_seconds` at 15 whatever the manifest asks for.

On `Expired` the run sends `POST /containers/<id>/stop?t=1` and answers
`{timed_out: true, stdout: '', stderr: ''}`. Nothing partial is answered: what
arrived before the deadline passed is not a whole payload.

Stopping the container is the whole of it. `t=1` is SIGTERM and then SIGKILL a
second later, so cyber-dojo.sh's own EXIT trap still gets its chance to run,
and the container is created with `AutoRemove`, so the daemon disposes of it
once it exits.

`runner.rb` logs the timed-out run and answers `timed_out_result`: an empty
result carrying status 142. What the run said goes to the log rather than to
the browser.

## Why the deadline is absolute

The deadline bounds the whole run rather than each read of it. A container
dribbling output would never trip a timeout that started again on every read,
and `IO#timeout=` on its own bounds a single read, which is why the budget is
recomputed before each one. That needs the reading to be a loop rather than a
read to EOF, and it is: `DockerAttachFrames.demultiplex` reads frame by frame.

The trickle is reachable by a determined kata, though not by a learner doing
anything normal. cyber-dojo.sh's own stdout is redirected to a file, but the
container's stdout is the attach stream, and everything inside runs as the
sandbox user, so a process can write to it directly through `/proc/1/fd/1`,
bypassing `send_tgz`. Such a kata also corrupts the tgz, which the gzip CRC
catches.

## Why the stdin write is not bounded

`send_tgz` writes the incoming tgz to the hijacked socket and shuts down the
writing half, on the same thread that then reads, so a write that blocked would
block before the deadline was armed.

Blocking needs a payload of megabytes and a container that never reads its
stdin, and the body's first act is `tar -C / -zxf -`.
`docs/profiling/measure_stdin_bytes_before_docker_run_blocks.rb` measures how
much goes in before a container that never drains stalls. It measures the CLI's
stdin rather than a hijacked socket, and it is a Docker Desktop figure either
way, so treat the magnitude as indicative rather than portable.

## Why no signals

There is no CLI process to signal, so the stop is the only way the run ends.
`docs/profiling/time_docker_stop_alone_to_cli_exit.rb` and
`docs/profiling/time_timeout_path_api_vs_cli.rb` hold the measurements behind
preferring the stop even when there was a process to signal: signalling a fork
bomb does not always take the same way out, and killing the reader can return a
partial payload for the runner to parse.

A fork bomb ignores the SIGTERM, so `t=1`'s SIGKILL is what ends it and the
overshoot is about a second. That is the container refusing to go rather than
the way it was asked. What matters for a bomb is that the run terminates and
that nothing is left behind.

## Testing

`test/server/deadline_reader_test.rb` pins the reader itself: a read with time
left, a deadline already past, and a read still waiting when the deadline
passes.

`test/server/daemon_run_test.rb` c9Gf14 drives the timed-out path with a
stubbed socket, asserting the stop is `POST /containers/c0ffee/stop?t=1` and
that the result carries no partial payload.

c9Gf18 pins the same thing against the real daemon, using a sleeping kata. A
sleep is what makes that test deterministic: it sends nothing before the
deadline and nothing kills its PID 1, so the deadline is the only way the run
can end.

c9Gf17 runs a real fork bomb, which saturates `PidsLimit` so that `send_tgz`
cannot fork the `find`, `file`, `tar` and `gzip` its EXIT trap needs, and
asserts only that no container is left behind. A bomb has two ends, and which
one it takes is a race:

- the fork failures leave PID 1 stuck, so the deadline expires and the run
  answers `timed_out` with empty strings
- the fork failures take PID 1 down with them, so the attach stream ends and
  the run answers whatever complete frames arrived, which need not be nothing

So neither the timeout nor an empty stdout can be asserted of a bomb. A payload
that arrives whole but does not inflate is `runner.rb`'s to answer faulty for,
not `daemon_run.rb`'s.

`test/server/run_timed_out_test.rb` e7Kc20 pins what `runner.rb` makes of a
timed-out run: outcome `timed_out`, status 142, and the run logged.
