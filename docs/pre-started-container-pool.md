# A pool of pre-started containers

The plan for taking container creation off a test-run, which
profiling/where-the-traffic-light-time-goes.txt measures and argues for. Read
that first: this file says only what has to be built, and in what order.

A test-run is what the [test] button in the browser asks for: one run of the
kata's cyber-dojo.sh in a container, answered with a traffic light.

Nothing is recycled. A spare has only ever run sleep, serves exactly one exec,
and is then discarded: one test-run, one container, nothing reused and nothing
to reset. The pool pre-pays create and start; it does not hand a used container
to the next test-run.

A miss falls back to the path runner.rb takes today, so correctness never
depends on the pool. That is what makes the whole thing shippable behind a low
cap, before the aws-prod cluster gains any memory: the cap trades away speed,
never behaviour.

## 0. A test-run that execs into a container behaves like one that creates its own

The test-run moves from "create a container around this run" to "exec into a
container that already exists", so everything the run relies on has to survive
that move. This is what decides whether the rest is buildable at all, so it
comes first.

profiling/compare_exec_vs_run_container_properties.rb answers it, running the
same command both ways under the production config with the same id, so that
any line differing is a real divergence. It reports none. Every property the
contracts in test/client/container_properties_test.rb pin arrives the same
either way: all of ulimit -a including data, core, nproc and file locks
(3A8D99), HOME and the CYBER_DOJO_* vars (3A8D98), /proc/1, /etc/passwd, uid,
gid, and the sandbox's ownership and writability (3A8D97).

So an exec'd process does inherit what HostConfig.Ulimits sets, and the ulimits
do not have to be re-applied as `ulimit` builtins inside the exec'd command.

Exec honours Env, which is how the vars belonging to one test-run reach a
container created before they were known. CYBER_DOJO_ID is for tracing rather
than for the kata to act on, so it never constrained the design, but it does
not have to be given up either.

## 1. Split CyberDojoShContainerConfig

Into a per-image half (Image, User, HostConfig, CYBER_DOJO_IMAGE_NAME,
CYBER_DOJO_SANDBOX) and a per-test-run half (CYBER_DOJO_ID, and the stdio
group, which a spare does not want). A spare is the per-image half with a sleep
Cmd, stdin off, and a label marking it a runner spare and naming its image.

## 2. An exec'd test-run beside CyberDojoShRunner

Exec create, then a hijacked POST /exec/{id}/start.
profiling/time_test_run_via_daemon_api_vs_cli.rb is a working sketch of both.
DockerAttachFrames and DeadlineReader carry over untouched, because the frames
and the deadline are the same either way.

DockerSocket#attach does not, though. It sends Content-Length: 0, and
exec-start carries a body saying Detach and Tty, so it needs a hijack that can
take one. compare_exec_vs_run_container_properties.rb writes that request
itself and is the shape to lift.

## 3. The timeout path

CyberDojoShRunner's stop leans on AutoRemove disposing of the container once it
stops. A pooled container needs its exec killed, and is then discarded rather than
returned, because what a timed-out kata left running is not something the next
test-run should inherit.

## 4. ContainerPool, per worker, shaped like Puller

In-process on Context and mutex-guarded, the way Puller holds @pulled.

It differs from Puller in what a restart costs. The daemon's image store is the
ground truth behind @pulled, so losing it costs one redundant pull the daemon
answers at once. Losing the pool's state leaks running containers instead, so
the daemon has to be the ground truth here too: spares are labelled at create
time, and a worker discovers and reaps them through
GET /containers/json?filters=label=... rather than trusting its own memory.

That label query is for reaping, not for claiming, and the difference is the
whole reason the pool is per worker rather than shared across them. Reaping is
background work. Claiming is on the test-run, which an API-driven pool answers
in 14.2ms against 114.1ms today, so a daemon round trip spends against a 14ms
budget and not a 114ms one. Forked workers share no memory, so a shared pool
could only be claimed from through the daemon, and the claim would have to be
atomic (a rename that fails when another worker got there first) rather than a
list.

Which is to say the two designs differ only in when a worker claims. Claim
ahead of the test-run and the result is a per-worker pool by definition. Claim
during it and the learner pays the round trip. A shared pool is therefore not a
simpler pool, it is this pool with the claim moved onto the path the whole
exercise exists to shorten, so it is ruled out.

The thread that reaps a used container creates its successor in the same
breath, so each test-run refills the pool it drained. Container names stay
unique per forked worker.

## 5. A cap divided by Etc.nprocessors

puma forks a worker per processor, and each worker would hold its own pool, so
a per-worker cap of ten on a four-core node is forty spares and not ten. The
number that is configured is therefore the node's, and each worker takes a
share of it.

An idle container costs the machine about 12MB, so ten spares is about 120MB.
That is what a low cap buys and what it costs.

## 6. Wire it into runner.rb and pull_image

In runner.rb, take a spare for the image; if there is none, do the test-run
exactly as today.

Step 4 only refills a pool that a test-run has already drained, so on its own
the first test-run for an image misses every time. pull_image is what seeds it.
Creator calls POST /pull_image(id, image_name) when a kata is created,
which is the earliest moment the runner learns an image is about to be wanted,
and is already the hook for exactly this kind of preparation. Once the pull
finishes, create a spare for that image.

The id that pull_image carries is not the key, and does not become one. Puller
keys @pulled and @pulling on image_name and underscores the id it is passed;
the pool keys on image_name for the same reason. Nothing is recycled, so there
is no per-kata state for a spare to hold, and two katas on the same language
share both the pull and the pool.

Seeding puts a second caller of /containers/create in a background thread, and
that create can 404 for an image Puller wrongly believes is present. See
docs/a-missing-image-recovers-only-through-puller.md: the pool should treat
that 404 the way the run path will, as proof the image has gone, rather than
retrying quietly for ever.

Seeding is best-effort, not a guarantee. puma forks a worker per processor and
each worker holds its own pool, so the pull_image request warms only the pool
of the worker that serves it. A test-run landing on a different worker still
misses, falls back, and that worker then warms itself through step 4's refill.
The seed removes the first miss on one worker rather than on all of them.

## 7. A spare's lifetime is its sleep

AutoRemove reaps a spare whose sleep has ended, which bounds a leak without any
bookkeeping to get wrong. The duration is chosen against the refill rate.

That duration also decides how long a spare pins its image. A spare is a
container referencing an image, and docker will not remove an image that has
containers, so an image with spares cannot be reclaimed: not by the rules in
docs/purge-stale-images.txt, and not by kubelet image garbage collection.

Which is worth having. docs/a-missing-image-recovers-only-through-puller.md
describes the one unrecoverable state the runner has, an image that Puller's
add-only @pulled believes is present after it has left the node. Pinning makes
that state unreachable for any image the pool is keeping warm, and the images
at risk of reclamation are the cold ones, which by definition have no spares.
So the pool narrows that window rather than widening it. It does not close it,
and the 404 from create is still where recovery has to live.

The cost is the other side of the same fact: a purge cannot reclaim an image
the moment it decides to. It has to wait out the sleep of the last spare, once
no test-run is refilling them. That is a delay rather than a deadlock, and
choosing the sleep duration is choosing how long a purge waits.

Not verified here: that docker refuses to remove an image referenced by a
running container. It is the documented behaviour, and checking it means
creating containers, so it belongs with the probes rather than in this file.

## 8. Tests, then measure

Re-run profiling/measure_idle_warm_container_cost.sh to confirm what the chosen
cap really costs on the node it will run on.

## Order

With 0 answered, the risk that is left sits in 1 to 3, which is where the
test-run changes shape. Steps 4 to 8 are mechanical.
