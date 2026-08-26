# The timeout path

How a timed-out press ends, and why it is shaped this way.

## What happens

`capture3_with_timeout.rb` spawns the docker CLI, detaches it, and waits with
`waiter.join(max_seconds)`. `Thread#join` answers `nil` when the wait runs out
with the process still alive, so timing out is a returned value rather than a
raised exception. There is no `Timeout`, and nothing reads with a deadline.

On expiry it runs `docker stop --time 1 <container_name>`. Stopping the
container is the whole of it: `docker run` exits, its stdout closes, and the
reader threads reach EOF. No signal is sent to the CLI, so there is no process
group. `--time 1` is SIGTERM and then SIGKILL a second later, so
cyber-dojo.sh's own EXIT trap still gets its chance to run.

The stop is synchronous, and a thread would buy nothing: the CLI cannot exit
before the container does, and it exits about 25ms after the stop returns.

A second `waiter.join(GRACE_SECONDS)` follows, and the CLI process is killed if
that also runs out. That is the backstop for a stop which never takes effect,
eg an unresponsive daemon; without it `waiter.value` waits for ever. Reaching
it means something is wrong rather than slow.

`runner.rb` keeps the log line for a failing stop. `run` carries the stop's
outcome back under `:docker_stop`, and `runner.rb` takes that key off, because
everything left in the run reaches the browser.

## Why the readers need no deadline

The reader threads read to EOF. The CLI exiting closes their pipes, and the
backstop guarantees the CLI exits, so a deadline on the reads would add a
mechanism without adding a bound.

`IO#timeout=` would in any case be the wrong tool as a one-liner: it bounds a
single read, not a read to EOF, so a stream that keeps trickling never trips
it. Bounding the whole press that way needs an absolute deadline recomputed
before each read, which means replacing `in.read` with a chunk loop.

Note the trickle is reachable by a determined kata, though not by a learner
doing anything normal. cyber-dojo.sh's own stdout is redirected to a file, but
tini runs as the sandbox user, so a child can write to the container's stdout
through `/proc/1/fd/1`, bypassing `send_tgz`. Such a kata also corrupts the
tgz, which the gzip CRC catches.

## Why the stdin write is not bounded

`spawn_detached_process` writes the incoming tgz to the CLI's stdin on the same
thread that then joins, so a write that blocked would block before the deadline
was armed. `docs/profiling/measure_stdin_bytes_before_docker_run_blocks.rb`
measures how much goes in first:

```
stdin filled                        KB accepted outcome
bare pipe, nobody reading                    64 stalled after 2s
docker run, never reads stdin              3328 stalled after 2s
docker run, drains stdin                  65536 no stall
```

So the CLI absorbs about 3.25MB beyond the OS pipe buffer, and a container that
drains takes 64MB without pausing. Blocking needs a payload over ~3.25MB and a
container that never reads stdin, and the body's first act is
`tar -C / -zxf -`. The 3.25MB is a Docker Desktop figure, so treat the
magnitude as indicative rather than portable.

## What the stop costs

`docs/profiling/time_docker_stop_alone_to_cli_exit.rb` measures a timed-out
press ended by the stop alone against one ended by signalling the CLI first.
Two katas: a `sleep`, and the shell fork bomb from
`test/client/robustness_test.rb` 1B5CD6, which saturates `--pids-limit` so that
`send_tgz` cannot fork the `find`, `file`, `tar` and `gzip` its EXIT trap needs.
`max_seconds` is 2, and the figures are milliseconds past it:

```
timed-out press                    overshoot   stop to exit   stop
sleep:     kill group, then stop        86.3              -      -
sleep:     stop only, no signals       105.1          100.0   76.7
fork bomb: kill group, then stop     unstable              -      -
fork bomb: stop only, no signals      1110.2         1106.1 1082.9
```

So the stop costs about 20ms on a press where the learner has already waited
`max_seconds`.

The fork bomb ignores the SIGTERM, so `--time 1`'s SIGKILL is what ends it and
the overshoot is about a second. That is the same second either way; it is the
container refusing to go, not the way it was asked. What matters for a bomb is
that the press terminates and that nothing is left behind, and the probe checks
the second of those directly: `docker ps --all` lists no survivors.

The signalling row is the unstable one. A fork bomb does not always take the
same way out, and killing the CLI can return a partial payload for the runner
to parse, which the stop-first path does not.

## Testing

`test/server/docker_stop_test.rb` drives the timed-out path with stubs,
asserting the exact `docker stop --time 1 cyber_dojo_runner_...` command.
`test/server/run_timed_out_test.rb` c7Ag55 pins the two deadlines the run is
bounded by, and c7Ag59 pins the backstop kill.

Note two traps in those doubles:

- `BashShellerStub#capture(command) { ... }` yields when the stub is
  *registered*, not when it is called, so a flag set inside that block proves
  nothing. `teardown` is what proves a stub was consumed, and nothing calls it
  automatically.
- the threader stub in `docker_stop_test.rb` hands the stdout and stderr
  readers `''`. That is harmless on the timed-out path, where no payload is
  expected, but it silently empties the payload on any test of a successful
  run.
