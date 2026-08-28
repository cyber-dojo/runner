# A pool of pre-started containers

The plan for taking container creation off a test-run, which
docs/profiling/where-the-traffic-light-time-goes.txt measures and argues for.
Read that first: this file says only what has to be built, and in what order.

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

A probe answered it before any of this was built, running the same command both
ways under the production config with the same id so that any line differing
was a real divergence. It reported none, and the whole of
test/client/container_properties_test.rb now passes against the exec path,
which is the same answer arriving by a route that stays: all of ulimit -a
including data, core, nproc and file locks (3A8D99), HOME and the CYBER_DOJO_*
vars (3A8D98), /proc/1, /etc/passwd, uid, gid, and the sandbox's ownership and
writability (3A8D97).

The probe went with the config it compared against. Once no code creates a
container around its own run, a comparison against one measures something that
does not exist, and the contracts are the better record anyway.

So an exec'd process does inherit what HostConfig.Ulimits sets, and the ulimits
do not have to be re-applied as `ulimit` builtins inside the exec'd command.

Exec honours Env, which is how the vars belonging to one test-run reach a
container created before they were known. CYBER_DOJO_ID is for tracing rather
than for the kata to act on, so it never constrained the design, but it does
not have to be given up either.

## The first increment: steps 1 to 3, with no pool behind them

Steps 1 to 3 land together, and on their own. The test-run creates, starts and
execs inline: the container is still made on the test-run, and there is no
spare, no pool and no cap. Only the shape of the run changes.

That is worth doing as a step of its own because it is where all the risk is,
and because it can be checked. Step 0's evidence comes from a standalone probe;
this puts the exec path under the whole suite, with the contracts in
test/client/container_properties_test.rb pinning it from inside the real code.
Step 3 in particular earns its own red and green: killing an exec is not what
AutoRemove does today, and it should not arrive tangled up with pool
bookkeeping.

It is about 10ms slower than today, being create at about 16ms plus start at
about 48ms plus an exec'd run at 32.2ms, against 84.7ms for a cold docker run,
and slower again by the synchronous stop step 3 describes. So it is an
intermediate stable point rather than something to ship for its own sake. What
it buys is that steps 4 to 8 then change only when a container is created, and
never what a test-run does with one.

Two things it changed that reading ahead did not predict. Disposal had to come
with it rather than waiting for the pool, for the reason step 3 gives. And a
missing bash is now reported by the daemon refusing the exec rather than by tini
failing to exec it, because the container's own command is a sleep that an image
without bash runs perfectly well, so the message moves from the log's stderr to
its stdout. The outcome the learner gets is unchanged: still faulty, with
nothing on stdout or stderr. test/client/container_properties_test.rb 3A8D91
pins the new route.

Still owed a red test: create_exec does not check the code the daemon answered,
so a refused exec parses an error body into a nil id. create_container has had
that check since before any of this.

## 1. Split CyberDojoShContainerConfig

Into a per-image half (Image, User, HostConfig, CYBER_DOJO_IMAGE_NAME,
CYBER_DOJO_SANDBOX) and a per-test-run half (CYBER_DOJO_ID, and the stdio
group, which a spare does not want). A spare is the per-image half with a sleep
Cmd, stdin off, and a label marking it a runner spare and naming its image.

The image half is CyberDojoShContainerConfig.image_config and the run half is
exec_config, the run half being the body of the exec rather than of the create.
A spare is also created under a spare name, which step 4 says why: the label
cannot be changed later and the name can, so the name is what says a container
is still unclaimed.

## 2. An exec'd test-run inside CyberDojoShRunner

Exec create, then a hijacked POST /exec/{id}/start. CyberDojoShRunner does both
itself rather than a second class alongside it: once nothing creates a container
around its own run, a second class would only be a second timeout path to keep
right. DockerAttachFrames and DeadlineReader are untouched, because the frames
and the deadline are the same either way.

DockerSocket#attach takes an optional body, because exec-start carries one
saying Detach and Tty where attaching to a container carries none. The json
headers go in only when there is a body, so a bodyless attach is byte for byte
what it was. DockerDaemon holds the two endpoints as create_exec and start_exec.
An exec's own start is the hijack, so nothing attaches to a container.

## 3. Disposal, the timeout path included

Disposing of the container is the whole of this step, and not only the
timed-out case, because moving the kata onto an exec is what takes disposal off
AutoRemove. A container whose own Cmd is a sleep does not exit when the exec
finishes, so AutoRemove has nothing to react to and the container lives out its
sleep holding memory. That is a container per test-run, which scales with
traffic and not with any cap, so a run that finishes has to stop its container
exactly as a run that timed out does.

Stopping it on both paths is what step 2 already does, in an ensure so that the
answer is the same whichever way the read ended. The cost is that the stop is
synchronous: the run waits for the teardown, about 50ms of it. Step 4's reap
thread is where that moves, and until then the increment is correct rather than
as quick as it can be.

A pooled container needs its exec killed, and is then discarded rather than
returned, because what a timed-out kata left running is not something the next
test-run should inherit.

## 4. ContainerPool, per worker, shaped like Puller

In-process on Context and mutex-guarded, the way Puller holds @pulled.

It differs from Puller in what a restart costs. The daemon's image store is the
ground truth behind @pulled, so losing it costs one redundant pull the daemon
answers at once. Losing the pool's state leaks running containers instead, so
the daemon has to be the ground truth here too: spares are labelled and named
at create time, and a worker discovers them through GET /containers/json
rather than trusting its own memory.

Labels and names divide that work between them, because docker will change one
and not the other. A label cannot be changed after a container is created:
POST /containers/{id}/update takes a Labels body, answers {"Warnings":null},
and leaves the label as it was, so there is not even an error to notice. A name
can be changed, by POST /containers/{id}/rename, and the labels survive it.

So the label says what a container is for, and goes on saying it for as long as
the container exists: it marks one the runner made, and names the worker that
made it. That is what lets orphans be reaped, and what keeps a worker from
reaping a live peer's. A worker that dies leaves orphans, and step 7's sleep is
what bounds those rather than a peer adopting them.

The name says what a container is doing, and changes when that changes. A spare
is created under a spare name, and claiming one renames it to the name its
test-run runs under. That rename is what step 5 counts on, because nothing else
separates a spare from a container already serving a run: both carry the same
label, and both are merely running.

The rename need not sit on the test-run. Atomicity comes from the pool's own
mutex, one worker's spares being nobody else's to take, so the rename is
bookkeeping rather than the claim itself, and the thread that will later reap
the container can do it. Step 5's count is a target rather than a ceiling
already, so a window in which it still counts a claimed container is the kind
of looseness it is built for.

That query is for reaping and counting, not for claiming, and the difference is
the whole reason the pool is per worker rather than shared across them.
Reaping is background work. Claiming is on the test-run, which an API-driven
pool answers in 14.2ms against 114.1ms today, so a round trip spends against
a 14ms budget and not a 114ms one. Forked workers share no memory, so a
shared pool could only be claimed from through the daemon, and the claim would
have to be atomic (a rename that fails when another worker got there first)
rather than a list.

Which is to say the two designs differ only in when a worker claims. Claim
ahead of the test-run and the result is a per-worker pool by definition. Claim
during it and the learner pays the round trip. A shared pool is therefore not a
simpler pool, it is this pool with the claim moved onto the path the whole
exercise exists to shorten, so it is ruled out.

The thread that reaps a used container creates its successor in the same
breath, so each test-run refills the pool it drained. Container names stay
unique per forked worker.

## 5. A hard cap of eight, counted on the daemon

The cap's scope is the node, because the node is where the memory goes.
docs/docker-socket-privilege.md bind-mounts the host's socket into the runner,
so every runner process on a node talks to one daemon, and every spare any of
them creates is a container on that one node.

A worker cannot know how many peers it shares that node with. puma forks a
worker per processor, but how many runner pods kubernetes has placed on the
node is not visible from inside one of them. So the cap cannot be a number each
worker divides down into a private share: there is no divisor to divide by.

It does not need one. Before its background thread creates a spare, a worker
asks the daemon how many spares the node already holds and creates only if that
count is under the cap. The daemon is the registry, so nothing has to be
counted that cannot be seen, and nothing has to be recalculated when kubernetes
adds or removes a pod.

What that count filters on is the spare name, not the label. Step 4 has the
reason: a claimed container keeps the label it was created with, so a label
query counts spares and containers already serving a test-run alike. Gating the
cap on that number would make the pool starve itself under exactly the load it
exists for, since eight concurrent runs would fill a cap of eight on their own
and no spare would be created while they ran. Filtering on the name instead
means a claimed container leaves the count when it is renamed, and the cap goes
back to bounding what it was costed to bound: containers that are idle.

The count is taken when a spare is created and never when one is claimed.
Creating is background work and can afford the round trip that step 4 refuses
to put on the test-run.

Two workers can both read seven and both create, so the cap is a target rather
than a ceiling. The overshoot is bounded by how many workers create at once,
and costs about 12MB each, which is the right thing to be loose about.

The cap is a total across every image, not a target per image. A per-image cap
multiplies by however many languages happen to be hot, which is the one number
the runner does not control, so a per-image cap cannot be bounded in advance.
A worker that finds the node at its cap creates no spare at all, and the
test-run misses and falls back, which step 6 is what makes safe.

An idle container costs the machine about 12MB, so eight spares is about 96MB.
The aws-prod cluster has not been given any more memory, so that 96MB is the
whole budget the pool has to fit inside. Eight is chosen to disappear against
what the node already carries rather than to win as many hits as it can.
Raising it is a one-number change once the memory lands.

What eight costs is hit rate, and nothing else.
docs/profiling/where-the-traffic-light-time-goes.txt puts a pre-started
container at about 84ms off the 116.4ms a test-run costs today, and a miss is
that same 116.4ms path unchanged, so a press either wins or is exactly as it
was. There is no cap below which the pool stops paying, only one below which it
pays less often.

At eight across every worker on the node a worker holds about one spare, so the
window between claiming and the refill landing is a window in which that worker
misses. The refill runs after the test-run it drained, so that window is at
least a whole run long. This is what raising the cap buys: not a faster hit,
but the same 84ms hit more often.

Refilling concurrently with the run rather than after it would narrow that
window, at the cost of daemon work during the part of a test-run that is
latency-sensitive. Which of those wins is a measurement and not an argument,
and step 8 is where it belongs.

## 6. Wire it into runner.rb and pull_image

In runner.rb, take a spare for the image; if there is none, do the test-run
exactly as today.

Step 4 only refills a pool that a test-run has already drained, so on its own
the first test-run for an image misses every time. pull_image is what seeds it.
Creator calls POST /pull_image(id, image_name) when a kata is created,
which is the earliest moment the runner learns an image is about to be wanted,
and is already the hook for exactly this kind of preparation. Once the pull
finishes, create a spare for that image, through step 5's cap check like any
other create: seeding is one more background creator and gets no allowance of
its own.

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

Re-run docs/profiling/measure_idle_warm_container_cost.sh to confirm what the
cap of eight really costs on the node it will run on.

Two things section 5 leaves for measurement rather than argument: the hit rate
a cap of eight actually reaches, which is the whole of what the cap buys, and
whether refilling concurrently with the run beats refilling after it. Both are
small changes to the same thread.

## Order

With 0 answered, the risk that is left sits in 1 to 3, which is where the
test-run changes shape. So 1 to 3 land together and stop there, with the whole
suite green against an inline create, start and exec and no pool behind it.
That is the intermediate stable point, and it is described above the steps
themselves.

Steps 4 to 8 are mechanical, and each is small only because that point exists
to build from: they move when a container is created without touching what a
test-run does with one.
