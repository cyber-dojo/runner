# Simplify the timeout path

Two cleanups to how a timed-out press is handled. Neither needs the docker
daemon API, neither changes what the browser receives, and they are
independent of each other. They buy clarity rather than speed.

## What happens today

`capture3_with_timeout.rb` wraps `Timeout.timeout(max_seconds)` around waiting
for the docker CLI process to exit. When it fires:

```ruby
process.kill(:TERM, -pid)
return if waiter.join(1)
process.kill(:KILL, -pid)
```

The process was spawned with `pgroup: true` so that the negative pid addresses
the whole group. Separately, `runner.rb` calls
`threaded_docker_stop_container`, which shells `docker stop --time 1
<container_name>` on a thread. Its comment says why both are needed:

> If [docker run] times-out then Capture3WithTimeout makes process.kill() calls
> to kill the [docker rm] process. However, this does *not* kill the
> *container* the [docker run] initiated. Hence the [docker stop]

So the code kills a process that is not the thing that needs stopping, and
then stops the thing that needs stopping anyway.

## (a) Stop the container, and let the CLI exit by itself

When the container stops, `docker run` exits, its stdout closes, and the
runner's read completes. The signalling exists only because the stop is
currently second rather than first.

Reversing the order deletes `pgroup: true`, both `Process.kill` calls, the
`waiter.join(1)` grace, and `kill_process_group` entirely, and keeps the
`docker stop --time 1` that is already there. It also keeps the semantics
exactly: `--time 1` is SIGTERM then SIGKILL a second later, so cyber-dojo.sh's
own EXIT trap still gets its chance to run.

One coupling to resolve. `capture3_with_timeout.rb` does not know the
container's name: `runner.rb` builds the command and owns the stop. The
timeout path needs either the name passed in, or a callback it can invoke.

A backstop is still worth keeping. If the stop fails or the daemon is
unresponsive, killing the CLI process after a grace period stops the runner
waiting for ever. The point is that it becomes the exception rather than the
first move.

## (b) A read deadline instead of `Timeout.timeout`

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
overshooting `max_seconds` by 81ms, and the signal dance is only part of that.
The case for these changes is that the timeout path is the least exercised and
most intricate code in the runner, and it currently reaches for process
groups and signals to solve a problem that `docker stop` already solves.

## Unverified

That `docker stop` alone makes `docker run` exit promptly has not been
measured here. The probe above does both, so it does not separate them. Worth
measuring before (a) is written, because the whole argument rests on it.

## Testing

`test/server/docker_stop_test.rb` already drives the timed-out path with
stubs, asserting the exact `docker stop --time 1 cyber_dojo_runner_...`
command, so both changes can be driven from a failing test there.

Note two traps in those doubles, found while writing a similar test:

- `BashShellerStub#capture(command) { ... }` yields when the stub is
  *registered*, not when it is called, so a flag set inside that block proves
  nothing. `teardown` is what proves a stub was consumed, and nothing calls it
  automatically.
- the threader stub in `docker_stop_test.rb` hands the stdout and stderr
  readers `''`. That is harmless on the timed-out path, where no payload is
  expected, but it silently empties the payload on any test of a successful
  run.
