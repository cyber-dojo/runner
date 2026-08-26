# Simplify the timeout path

One cleanup remains to how a timed-out press is handled. It needs no docker
daemon API, and it buys clarity rather than speed.

## What happens today

`capture3_with_timeout.rb` wraps `Timeout.timeout(max_seconds)` around waiting
for the docker CLI process to exit. When it fires, `docker_stop` runs
`docker stop --time 1 <container_name>`.

Stopping the container is the whole of it. When the container stops,
`docker run` exits, its stdout closes, and the reader threads complete. No
signal is sent to the CLI, so the process group, the `Process.kill` calls and
the grace `join` are not needed. `--time 1` is SIGTERM and then SIGKILL a
second later, so cyber-dojo.sh's own EXIT trap still gets its chance to run.

The stop is synchronous, and a thread would buy nothing: the CLI cannot exit
before the container does, and it exits about 25ms after the stop returns.

`runner.rb` keeps the log line for a failing stop. `run` carries the stop's
outcome back under `:docker_stop`, and `runner.rb` takes that key off, because
everything left in the run reaches the browser.

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
that the press does terminate and that nothing is left behind, and the probe
checks the second of those directly: `docker ps --all` lists no survivors.

The signalling row is the unstable one. A fork bomb does not always take the
same way out, and killing the CLI can return a partial payload for the runner
to parse, which the stop-first path does not.

## A read deadline instead of `Timeout.timeout`

`Timeout` runs a second thread that raises inside whatever the first thread is
executing when the clock expires, which can be any line, including one in a
library. The payload arrives on a pipe, so the wait can be expressed as a
deadline on reading that pipe instead. Ruby 3.4, which the runner image has,
has `IO#timeout=`, which raises `IO::TimeoutError` from the read itself:

```ruby
stdout_pipe.timeout = deadline - now   # recomputed before each read
```

The deadline must be absolute and reapplied before each read. `IO#timeout=`
bounds one read, not the whole wait, so a container dribbling output would
never trip a per-read timeout.

`docs/profiling/time_timeout_path_api_vs_cli.rb` uses this shape, though with
`IO.select` rather than `IO#timeout=` because it has to run on an older host
ruby.

## What this is worth

Not much in milliseconds.
`docs/profiling/time_timeout_path_api_vs_cli.rb` measures the current path
overshooting `max_seconds` by 81ms, and the deadline is only part of that. The
case for the change is that the timeout path is the least exercised code in
the runner, and a deadline on the read it is actually waiting on is easier to
reason about than a thread that raises anywhere.

## The backstop that is not there

If `docker stop` never takes effect, `waiter.value` in the `ensure` block waits
for ever. Killing the CLI process after a grace period would bound that, as the
exception rather than the first move. Nothing measures how often it would fire.

## Testing

`test/server/docker_stop_test.rb` drives the timed-out path with stubs,
asserting the exact `docker stop --time 1 cyber_dojo_runner_...` command, and
`test/server/run_timed_out_test.rb` c7Ag55 pins that no signal is sent.

Note two traps in those doubles:

- `BashShellerStub#capture(command) { ... }` yields when the stub is
  *registered*, not when it is called, so a flag set inside that block proves
  nothing. `teardown` is what proves a stub was consumed, and nothing calls it
  automatically.
- the threader stub in `docker_stop_test.rb` hands the stdout and stderr
  readers `''`. That is harmless on the timed-out path, where no payload is
  expected, but it silently empties the payload on any test of a successful
  run.
