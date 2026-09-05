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

Two kinds of miss, and only the first is obvious. There may be no spare for the
image, which is the case the cap and the refill rate decide. Or there may be a
spare that turns out to be dead: its sleep ended, it was OOM-killed, an
operator removed it, the daemon restarted under it. Handing out a container
made earlier cannot rule that out, whereas creating one for the run cannot
suffer it, so this is the one way the pool could show a learner something they
would not have seen without it.

The bar is therefore stricter than "correctness never depends on the pool". No
test-run may answer faulty, or pulling, in a case where it would have answered
a traffic light with no pool behind it. Both kinds of miss take the same way
out: run the test-run as though the pool had been empty.

## The steps

| # | step | state |
| --- | --- | --- |
| 0 | An exec'd test-run behaves like one that creates its own container | answered, by measurement |
| 1 | Split CyberDojoShContainerConfig | done |
| 2 | An exec'd test-run inside CyberDojoShRunner | done |
| 3 | Disposal, the timeout path included | done |
| 4 | SparePool, per worker, shaped like NodeImages | done |
| 5 | A hard cap, counted on the daemon | done, at sixteen |
| 6 | Wire it into runner.rb and pull_image | done |
| 7 | A spare's lifetime is its sleep | done |
| 8 | Tests, then measure | done |
| 9 | A cap someone hosting their own server can set | not started; SPARES_PER_NODE is a constant |
| 10 | A pool per worker, filled by whoever shares an image_name | done |
| 11 | An allowlist of image_names, holding python_pytest alone | not started; what makes this shippable |
| 12 | A manifest may raise a limit, up to a ceiling the runner owns | not started; now a fallback, not a prerequisite |
| 13 | Limits set from what a kata uses | done |

Steps 1 to 3 are the intermediate stable point: the test-run has changed shape
and no pool sits behind it. Steps 4 to 8 and 10 are the pool. Steps 9 and 11 are
what decide where it may be turned on, and 11 is what the rest of this file's
later sections are about.

Step 13 was not foreseen. Sizing a cap needs a figure for what a container
costs, and both numbers behind that turned out to be guesses: the limits a
test-run runs under, and what an idle spare costs. Both are now measured, which
moved three of them and one of the answers:

| what | was | is | measured by |
| --- | --- | --- | --- |
| Memory | 2GB | 768MB | worst of 82 katas, 719.9MB, julia_test |
| /sandbox and /tmp tmpfs | 250M each | 64M each | worst of 82, 20MB and 1.2MB |
| fsize | 256MB | 16MB | largest file of 82, 3.4MB |
| an idle spare | 12MB | 5.2MB | measure_spare_cost_by_pss_slope.sh |

The last of those halves the RAM the pool needs, so four allowlisted image_names
at a depth of two now fit in the memory the node already has free, and only
eight need an ECS change.

Step 12 was a prerequisite when this was written, because fsize at 16MB killed
every BEAM start. The elixir and erlang start-points now pass +JMsingle true, so
the JIT creates no 64MiB memfd and both live inside the limit. What is left for
step 12 is an LTF that needs more and cannot be changed.

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

## 4. SparePool, per worker, shaped like NodeImages

In-process on Context and mutex-guarded, the way NodeImages holds @pulled.

Shaped like it, and deliberately not merged into it. The two are image-keyed
background-warmed caches alike, but they sit on opposite sides of a boundary:
no image means a test-run cannot go ahead at all and the learner gets pulling,
while no spare means it goes ahead exactly as today and is only slower. One
class doing both would make it easy for a spare-shaped failure to block a run,
which is the mistake a 404 from an exec create being read as a missing image
already was. They also differ in lifetime, in how many there are per image, and
in whether they are capped.

It differs from NodeImages in what a restart costs. The daemon's image store is
the ground truth behind @pulled, so losing it costs one redundant pull that the
daemon answers at once. Losing the pool's state leaks running containers
instead, so the daemon has to be the ground truth here too: spares are
labelled and named at create time, and a worker discovers them through
GET /containers/json rather than trusting its own memory.

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

A claim also has to look at how much of the spare's sleep is left, and decline
one that cannot outlast a whole run, discarding it and falling back. Step 7
has the reason: the sleep ending under a run that is already going kills the
kata part way and answers the learner faulty. What is left is in the worker's
own memory, since the worker created the spare, so this costs no daemon call
and nothing but a miss.

The threshold is not a number of its own. It is CyberDojoShRunner::RUN_SECONDS
plus CyberDojoShRunner::STOP_SECONDS, read from the runner that imposes both,
so raising either cannot leave the pool believing the old one.

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

## 5. A hard cap, counted on the daemon

The cap's scope is the node, because the node is where the memory goes.
docs/docker-socket-privilege.md bind-mounts the host's socket into the runner,
so every runner process on a node talks to one daemon, and every spare any of
them creates is a container on that one node.

A worker cannot know how many peers it shares that node with. puma forks a
worker per processor, but how many runner processes the node is running is not
visible from inside one of them, whether they were placed there by ECS, by a
docker compose file someone wrote themselves, or by anything else. So the cap
cannot be a number each worker divides down into a private share: there is no
divisor to divide by.

It does not need one. Before its background thread creates a spare, a worker
asks the daemon how many spares the node already holds and creates only if that
count is under the cap. The daemon is the registry, so nothing has to be
counted that cannot be seen, and nothing has to be recalculated when a runner
process is added or taken away.

What that count filters on is the spare name, not the label. Step 4 has the
reason: a claimed container keeps the label it was created with, so a label
query counts spares and containers already serving a test-run alike. Gating the
cap on that number would make the pool starve itself under exactly the load it
exists for, since as many concurrent runs as the cap would fill it on their own
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

An idle container costs the machine up to about 12MB, so sixteen spares is
about 192MB. That is host memory rather than the task's 768MB: the spares are
siblings of the runner on the EC2 host, not children of it.

Sixteen rather than the eight this section first argued for, because a claim
trades RAM for daemon CPU and aws-prod is shorter of CPU than of RAM. It runs
on c5a.xlarge: 4 cores, 8GiB, and a load average of about 4, so the cores are
saturated. 3GiB is in use with 0.6GiB free, and 192MB is a sixth of that free
memory. Whether most of the remaining 4.4GiB is reclaimable page cache is not
known here, and if it is, there is room to go further.

12MB is the safe end of a range rather than a figure.
docs/profiling/measure_idle_warm_container_cost.sh reads MemAvailable, which
moves with how much the host has free, and the same probe on the same machine
answered about 12MB each with 7.4GB available and about 5.2MB each with 5.7GB
available. What both runs agree on is the container's own use, 708KB and
776KB; everything above that is the shim and the daemon's bookkeeping. Size the
cap against the larger, because sizing it against the smaller overruns.

What the cap costs is hit rate, and nothing else.
docs/profiling/where-the-traffic-light-time-goes.txt puts a pre-started
container at about 84ms off the 116.4ms a test-run costs today, and a miss is
that same 116.4ms path unchanged, so a press either wins or is exactly as it
was. There is no cap below which the pool stops paying, only one below which it
pays less often.

A cap spread across every worker on the node leaves each worker holding few
spares, so the window between claiming and the refill landing is a window in
which that worker misses. The refill runs after the test-run it drained, so that window is at
least a whole run long. This is what raising the cap buys: not a faster hit,
but the same 84ms hit more often.

Refilling concurrently with the run rather than after it would narrow that
window, at the cost of daemon work during the part of a test-run that is
latency-sensitive. Which of those wins is a measurement and not an argument,
and step 8 is where it belongs.

## 6. Wire it into runner.rb and pull_image

In runner.rb, take a spare for the image; if there is none, do the test-run
exactly as today.

A spare that is refused is the same case arriving later. If create_exec or
start_exec answers a refusal for a claimed spare, discard it and do the
test-run exactly as today, rather than letting DaemonRefused reach the learner
as faulty. One retry, not a loop: a freshly created container failing the same
way is a real fault and should be reported as one.

The retry is clean because of where the refusal lands. run does create, start,
create_exec, start_exec, then send_tgz, so both exec calls come before the tgz
is written. A refusal there means the kata's files never left the runner and
there is no partial state to unpick, which is what makes falling back safe
rather than merely hopeful.

Distinguishing the two refusals matters here. A 404 from an exec create says
the container has gone, and a 409 says it is not running; neither says anything
about the image, which is why ImageMissing is a separate class and why a
refused exec must not reach NodeImages#forget. See
docs/a-missing-image-recovers-only-through-a-pull.md.

Step 4 only refills a pool that a test-run has already drained, so on its own
the first test-run for an image misses every time. pull_image is what seeds it.
Creator calls POST /pull_image(id, image_name) when a kata is created,
which is the earliest moment the runner learns an image is about to be wanted,
and is already the hook for exactly this kind of preparation. Once the pull
finishes, create a spare for that image, through step 5's cap check like any
other create: seeding is one more background creator and gets no allowance of
its own.

The id that pull_image carries is not the key, and does not become one.
NodeImages keys @pulled and @pulling on image_name and underscores the id;
the pool keys on image_name for the same reason. Nothing is recycled, so there
is no per-kata state for a spare to hold, and two katas on the same language
share both the pull and the pool.

Seeding puts a second caller of /containers/create in a background thread, and
that create can 404 for an image NodeImages wrongly believes is present. See
docs/a-missing-image-recovers-only-through-a-pull.md: the pool should treat
that 404 the way the run path will, as proof the image has gone, rather than
retrying quietly for ever.

Seeding is best-effort, not a guarantee. puma forks a worker per processor and
each worker holds its own pool, so the pull_image request warms only the pool
of the worker that serves it. A test-run landing on a different worker still
misses, falls back, and that worker then warms itself through step 4's refill.
The seed removes the first miss on one worker rather than on all of them.

## 7. A spare's lifetime is its sleep

AutoRemove reaps a spare whose sleep has ended, which bounds a leak without any
bookkeeping to get wrong.

The sleep ending under a run that is already going is the thing to design
against. An exec does not survive its container's PID 1, and a probe settles
what that costs: against a container sleeping 5 seconds, an exec wanting 10
prints 5 seconds of output and exits 137, which is SIGKILL. So a spare claimed
too near the end of its sleep has its kata killed part way.

The learner sees that as faulty rather than as a wrong colour. The exec stream
simply ends, so the runner reads a truncated gzip and runner.rb's
Zlib::GzipFile::Error rescue answers faulty with nothing on stdout or stderr.
Faulty for a kata that was fine is still worth not doing.

Step 4's claim is where it is avoided, because a worker created its spares and
so knows what is left of them without asking the daemon: it declines one that
cannot outlast a whole run and falls back, which costs a miss and nothing
else. The threshold is RUN_SECONDS plus STOP_SECONDS, read from
CyberDojoShRunner, with nothing added for the exec setup between the claim and
the deadline starting, which is milliseconds against them.

That makes the duration a three-way trade rather than a choice against the
refill rate. Too short and most of a spare's life is unclaimable: at sixty
seconds a spare can be claimed only for its first forty, so a third of every
spare is wasted and the refill rate has to cover it. Too long and a spare
leaked by a worker that died lingers. Too long and a purge waits, which is the
rest of this section. Three hundred seconds puts the waste near seven per cent
and makes a purge wait five minutes.

That duration also decides how long a spare pins its image. A spare is a
container referencing an image, and docker will not remove an image that has
containers, so an image with spares cannot be reclaimed: not by the rules in
docs/purge-stale-images.txt, and not by kubelet image garbage collection.

Which is worth having. docs/a-missing-image-recovers-only-through-a-pull.md
describes the one unrecoverable state the runner has, an image that the
add-only @pulled believes is present after it has left the node. Pinning makes
that state unreachable for any image the pool is keeping warm, and the images
at risk of reclamation are the cold ones, which by definition have no spares.
So the pool narrows that window rather than widening it. It does not close it,
and the 404 from create is still where recovery has to live.

The cost is the other side of the same fact: a purge cannot reclaim an image
the moment it decides to. It has to wait out the sleep of the last spare, once
no test-run is refilling them. That is a delay rather than a deadlock, and
choosing the sleep duration is choosing how long a purge waits.

### The sleep is the one number a worker could set for itself

Of everything the pool is configured with, the sleep is the only number that is
about learners rather than hardware. The three memory caps are about a node,
which does not change while it runs, so nothing is gained by deciding them at
run time. The sleep is about the gap between one test-run for an image_name and
the next, and that gap changes hour by hour: sixteen people on python_pytest
leave seconds between test-runs, one person leaves a minute, and the same LTF
is both at different times of day.

A worker can measure it. It serves the test-runs, so it can record when each
one for an image_name arrived, hit or miss, and a miss is the case worth
learning from. Keeping the last eight gaps in a ring per image_name is a few
floats.

The statistic has to be a high percentile rather than a mean, because the aim
is to cover the gap and a mean sits under most of the gaps it is averaging. One
long think would drag it the wrong way. Something like:

    sleep = clamp(p75_of_recent_gaps + longest_hold_seconds, 30, 120)

p75 is the gap the spare has to survive. longest_hold_seconds is the sixteen
that usable? insists on, so what survives is claimable rather than merely
alive. The floor stops a busy LTF choosing a sleep with no window left in it
once sixteen is taken; the ceiling stops a quiet one holding memory for as long
as it likes.

Nothing here is built, and it should not be until the fixed sleep has run in
production long enough to say what the gaps actually are. The ring buffer is
also the thing that would answer that: logging p75 per image_name is most of
the work and none of the risk.

Not verified here: that docker refuses to remove an image referenced by a
running container. It is the documented behaviour, and checking it means
creating containers, so it belongs with the probes rather than in this file.

## 8. Tests, then measure

Re-run docs/profiling/measure_idle_warm_container_cost.sh to confirm what the
cap really costs on the node it will run on.

Section 5 leaves two things for measurement rather than argument. Both are
answered.

Where the refill belongs: with the test-run, after the payload has been read.
A run now warms a spare on its way out, whether it claimed one or made its own
container. The warm is on its own thread, so nothing on the path to the answer
waits for it, and it comes after the payload so its create and its start do not
compete with the kata for the daemon.

What the cap buys: measured by timing the client suite, which makes about forty
real test-runs. Every timing starts from the same slate, with the spare
containers removed and busybox:glibc absent, because a spare made from an image
holds that image and the pull test needs it gone.

| cap | one puma worker |
|-----|-----------------|
| 0   | 26.7s, 26.9s    |
| 8   | 24.2s, 25.2s    |
| 32  | 25.2s, 25.5s    |

What one hit is worth, and what the pool costs a miss, are separate numbers.
docs/profiling/time_hit_vs_miss_under_load.sh times a hit as the exec and the
stop, and a miss as the create and start those follow, with idle containers
standing in the background.

| idle | hit ms | miss ms | hit x8 ms | miss x8 ms |
|------|--------|---------|-----------|------------|
| 0    | 70     | 171     | 23        | 67         |
| 8    | 76     | 208     | 24        | 60         |
| 32   | 80     | 220     | 23        | 65         |

A hit saves 101ms with no pool standing, and 140ms with thirty-two idle. The
saving grows because idle containers tax a miss harder than a hit: the miss
goes from 171ms to 220ms where the hit goes from 70ms to 80ms. Eight of them at
once, the last two columns, cost the daemon far less per run than one at a
time, and the saving there is about 40ms.

So a cap of eight takes about two seconds off twenty-seven, and raising it to
thirty-two takes off no more. That is one worker on one image_name, which is
the case a cap of eight already covers. It says nothing about a node running
several workers and several LTFs, which is what section 10 is about and what
the cap of sixteen is sized for.

The same suite against ten workers shows no difference between any of the three
caps. Section 10 is why.

## 9. A cap someone hosting their own server can set

Anyone running their own server with the cyber-dojo shell script and commander
gets whatever cap is compiled in, on hardware nobody here has sized. So the cap
has to be settable, and the way it is settable already exists: commander's
`--port`.

That chain is worth following rather than inventing another. Its default lives
in cyberdojo/versioner and reaches commander through dot_env. up.rb takes
`--port` from the command line or falls back to that default, having declared
`--port` in the `knowns` allowlist, an undeclared flag being a hard error, and
in the help text. It then merges the value into the env_vars it hands to
docker compose, and a compose fragment passes it to the service.

The cap follows it with one deliberate difference: no new versioner entry, so
the default is duplicated instead. commander carries its own literal, because
dot_env cannot supply what versioner does not hold.

    commander app/server/up.rb
      --spares into knowns, into the help table, and
      spares = up_command_line['--spares'] ||
               ENV['CYBER_DOJO_RUNNER_SPARES_PER_NODE'] || '8'
      merged into env_vars

    commander app/docker-compose/environment.yml
      a runner stanza passing CYBER_DOJO_RUNNER_SPARES_PER_NODE
      (only web is given any env var today, so this is new)

    runner spare_pool.rb
      SPARES_PER_NODE read from ENV, defaulting to 8

Duplicating the default has a consequence worth stating, because it is not
symmetrical. commander always sets the var, from the flag or from its own
literal, so in a commander-run server commander's number always wins and the
runner's constant never applies. The runner's constant is what the test suite
and any deployment that sets nothing will use. If the two ever disagree, the
one in the runner is the one that looks authoritative while having no effect
where it matters most.

Zero is the setting that matters most to a self-hoster, and it has to mean no
pool rather than an empty one: no spare is ever created, every test-run creates
its own container, and the runner behaves exactly as it did before any of this.
That is also the switch that makes the whole feature safe to ship to people
whose hardware we cannot see.

## 10. A pool per worker, filled by whoever shares an image_name

puma forks one worker per processor, which is ten on the node this was measured
on, and each worker holds its own pool. A warm goes into the pool of whichever
worker served that test-run. The next test-run goes to whichever worker is
free.

For one person practising alone, that divides the hit rate by the worker count.
Their next test-run lands on the worker holding their spare about one time in
ten, and the other nine spares sit unclaimed until they expire. The client
suite is exactly this shape, one user's test-runs one after another, which is
why ten workers show no gain where one worker shows two seconds in
twenty-seven.

That shape is the worst case rather than the expected one. The pool is keyed by
image_name, so what fills a worker's pool is how many test-runs share an LTF,
and not who is practising with whom. Sixteen people practising as a team are
one such stream. So are five people who have never met, each on their own
exercise, as long as all five chose python with pytest: to the pool they are
one stream of test-runs on one image_name. A handful of LTFs carry most of the
traffic, so under any real load every worker's pool warms and stays warm.

What binds under that load is the cap against the worker count. The cap is the
node's and the pools are the workers', so a cap below the worker count leaves
some workers holding nothing however hot the image_name is, and with several
LTFs hot at once it cannot come close.

So the number to choose is the worker count times the number of image_names hot
at once. Two workers a task and three tasks is six pools, so sixteen is between
two and three LTFs in each of them. That is what the cap is now set to, and
section 5 carries the memory it costs.

### Four places a limit can sit

There are four places a limit can sit, and they are not alternatives. Each
bounds something the others cannot see. The first three are about spares,
which are containers waiting. The fourth is about containers working.

  o) per image_name, per worker. The size of one queue. A limit of one gives
     every worker a spare for every LTF it is asked for, which is the shape
     that stops a worker holding python_pytest from missing on bash_bats.
     Checked by reading one queue's length, in this process.
  o) per worker, across every image_name. The sum of that worker's queues.
     This is what bounds a worker whose traffic keeps finding new LTFs, which
     the first limit cannot: nothing bounds how many image_names are hot.
     Checked by summing the hash, in this process.
  o) per node, across every worker and every runner process. What section 5
     already has, at sixteen. It is the only one that can see the memory that
     actually matters, and the only one that costs a daemon call.
  o) how many test-runs are in flight at once, which is how many containers
     are running a kata rather than waiting to. Nothing names this today. It
     is set by workers times threads in config/puma.rb, as a side effect of
     choosing those for other reasons, and a container running a kata costs
     far more than an idle one: it holds two tmpfs mounts and whatever the
     kata compiles into them.

Only the third exists today. The first two are free to check, and the third is
already on the warm's own thread, so adding the first two costs the test-run
nothing.

Sized together they multiply: a per-image_name limit of one, over however many
LTFs a worker sees, over however many workers the node runs. The node cap is
the ceiling that makes that product safe, and the two inner limits are what
stop the node cap being spent on one worker.

### An allowlist leaves two, and only one of them is tuned

Naming which image_names a spare may be held for changes the shape above. The
second cap exists only because "nothing bounds how many image_names are hot",
and a list of them bounds it by construction, so there is nothing left for that
cap to enforce. The first stops being a cap and becomes a queue depth, a
constant of the design rather than a number to tune. The fourth was never the
pool's: it is set in config/puma.rb, it is set the same way with no pool at all,
and the pool neither reads nor worsens it.

What remains is the allowlist and the node cap. The node cap is the one that
cannot be replaced, for the reason section 5 gives: a worker cannot see how many
runner processes share its node, so nothing computed inside one of them bounds
the product. It is also what makes raising the task count safe. Six tasks do not
hold twice the spares of three; they compete for the same cap, and what gives is
the hit rate, which costs latency and nothing else.

The depth and the node cap have to be chosen together, because the cap can make
a depth unreachable. Three image_names at a depth of two, over six pools, wants
thirty-six spares against a cap of sixteen. The cap binds, less than half the
queues fill, and which ones fill is a race between workers. The same three
image_names at a depth of one want eighteen and get sixteen, which is nearly
every queue. So a deeper queue is only worth asking for if the cap rises with
it, or if the allowlist is shorter.

The starting point is one image_name, python_pytest, at a depth of two. That is
what makes the cap need no change: one image_name over six pools at that depth
wants twelve spares against a cap of sixteen, so every queue fills and the cap
is not what binds. It is also the whole of the memory already costed, twelve
containers at about 12MB being about 144MB of the 192MB sixteen was sized for.

Adding image_names is what makes the cap bind, and the arithmetic says when.
Three at a depth of two over six pools wants thirty-six against a cap of
sixteen: less than half the queues fill, and which ones fill is a race between
workers. So the second image_name is the point at which either the depth drops
to one or the cap rises, and neither should be guessed at before the first one's
hit rate is read.

Against that, a depth of one means a worker with eight threads serving one hot
image_name has one spare and misses on the other seven runs of a burst until it
refills. Misses cost what a test-run costs today, so this is a question about
how much of the win is collected rather than about safety, and
docs/profiling/time_hit_vs_miss_under_load.sh is what answers it.

### What growing the allowlist costs in RAM

Raising the cap is free; the memory behind it is not, and buying it means an ECS
change and the downtime that comes with it. So the sizes are worked out here
rather than discovered one LTF at a time.

Spares are LTFs times depth times six pools, at 5.2MB each.
docs/profiling/measure_spare_cost_by_pss_slope.sh measures that by summing every
process's Pss at several idle counts and taking the slope, which answers 5.2MB at
sixteen idle containers and 5.2MB again at thirty-two. Against the 614MB
Graham's report leaves free:

| LTFs | cap needed | spares | spare RAM | of today's free |
| --- | --- | --- | --- | --- |
| 1 | 16 | 12 | 62MB | 10% |
| 2 | 24 | 24 | 125MB | 20% |
| 4 | 48 | 48 | 250MB | 41% |
| 8 | 96 | 96 | 499MB | 81% |

At a depth of one every row halves, so eight LTFs there costs what four cost at
a depth of two.

So four LTFs at a depth of two fits inside today's free memory, and only eight
needs more. To keep today's slack after the spares, the increase needed is
nothing up to four LTFs and about 0.5GiB for eight. There is no 0.5GiB to buy:
c5a.xlarge is 8GiB and the step is 16GiB, either m5a.xlarge keeping four vCPU or
c5a.2xlarge doubling both. Either covers every row above with about 8GiB left
over, so one move covers the whole table and there is no intermediate worth
planning for.

Two things to hold against that. 5.2MB is process memory, Pss counting no
kernel memory a container costs, so the true figure is above it and below the
12MB that MemAvailable suggested; the rows are therefore a floor rather than a
bound. And spares are the smaller consumer either way: sixteen test-runs in
flight at up to 768MB each dwarf them, so RAM bought for this should be sized
for the containers doing the work, with the spares as rounding.

### Later: an allowlist that maintains itself

A list someone edits is a list that goes stale. The two ways it goes stale are
not the same check, and neither needs anything the pool does not already see.

  o) an image_name in the list that nothing has asked for lately. The pool
     already timestamps a claim, so idleness is readable without new
     bookkeeping.
  o) an image_name not in the list that test-runs keep asking for. Each of
     those is already a miss, and the miss path already runs, so demand is
     learned from work that happens either way.

Three things such a policy needs. It belongs per worker, not per node: a worker
sees only its own traffic and owns only its own pools, and two workers holding
different lists is harmless, which is the reason the inner caps were free.
It needs hysteresis, because an image_name at the boundary would otherwise be
admitted and evicted in a loop, each turn costing a create and a discard; admit
on several misses inside a window, evict after an idle period much longer than
that window. And it needs the list length held at whatever the static list was,
so the memory already costed does not move.

A swap is a queueful rather than a container. Evicting one image_name discards
depth times pools spares, twelve at a depth of two, and admitting its
replacement creates twelve more, so one swap is twenty-four calls on the daemon.
All of it is on the warm and reap threads, so no learner waits for it, but it is
the same daemon whose bookkeeping is what makes a miss slower, which is a second
reason to swap rarely.

Evict before admitting, or admission stalls silently. Creating the new
image_name's spares while the old one's are still held puts twice a queueful on
the node, twenty-four where the cap is sixteen, and node_is_full? then declines
to create: the image_name just admitted would hold no spares at all until the
eviction finished, which reads as a policy that does not work rather than one
that is waiting. So eviction completes first, and the idle window is long
enough that one swap never overlaps the next.

This is later work, and deliberately so. It reintroduces a tunable policy where
the static list is one value, and it cannot be sized without hit-rate figures
that only the static list can produce.

### What main measured, and what the allowlist answers

main's 289a473f tried this pool and settled on not having one, landing the parts
worth keeping and none of the pool. Its figures are better than the ones above,
because they were taken with the pool built rather than argued from a container's
idle cost, and two of them contradict this file:

  o) a miss gets slower as the pool grows. A create-and-remove went from 183ms
     to 225ms at 50 idle containers, where section 5 says no slowdown is
     detectable up to 50. Idle containers are containers the daemon tracks.
  o) finding a spare costs a listing, and a listing goes from 1.3ms empty to
     50.5ms at 32 tracked. So at the sizes worth having, finding a spare costs
     what making a container costs.

And its headline: a hit saves about 100ms against a test-run a learner already
experiences as under four seconds, and about 180ms under load.

Both of the costs scale with how many containers the daemon is tracking, which
is the quantity an allowlist sets. One image_name at a depth of two over six
pools is twelve spares, not thirty-two and not fifty. So
docs/profiling/time_ls_vs_create_vs_start.rb was re-run at the sizes this
design asks for:

    tracked      ls ms    create ms    start ms
          0        1.3         40.5        50.2
          6       11.7         41.2        48.4
         12       25.6         43.0        49.4
         16       30.9         45.2        50.2
         32       52.1         50.4        50.4

The two columns answer differently, and only one of them is on a test-run's
path.

The listing is not. A claim reads one queue in this process; the only listing
the runner does is `SparePool#node_is_full?`, on the warm thread, after the
test-run it followed has already answered. So the 52.1ms at thirty-two prices
the shared pool, where a claim asks the daemon which spares the node holds, and
this design has never done that. An argument that the pool puts a listing on the
learner's path is an argument about a different design, and should be met with
this paragraph rather than re-measured.

The miss is on the path, and it does grow: create goes from 40.5ms at nothing
tracked to 43.0ms at twelve. That is about 2.5ms against a create and start of
about 92ms, under 3%, where main's 42ms was create-and-remove at fifty. So the
objection is real and its size is a function of the cap, which is the thing an
allowlist holds down.

Two things follow for this file. Section 5 argues its cap from memory alone, and
should argue it from the listing and the miss penalty as well, because those bind
sooner. And the 50.5ms listing is what killed sharing pools between workers,
which this design never did: a claim reads one queue in its own process, and only
warming asks the daemon, on a thread nobody waits on.

## 12. A manifest may raise a limit, up to a ceiling the runner owns

The limits in CyberDojoShHostConfig are one set for 82 start-points, so they are
either loose enough for the worst of them or tight enough to break it. Measured,
the spread is wide: docs/profiling/measure_sandbox_high_water_marks.rb puts the
largest sandbox at 20MB and the largest file it can see at 3.4MB, while
elixir_exunit needs an fsize above 16MB for a write that probe never sees, and
julia_test peaks at 719.9MB of memory where the next highest is 523MB.

So the default is set for the common case and an LTF may ask for more. A new
manifest key, limits, carrying the same names CyberDojoShHostConfig uses.

Clamped, not obeyed. A manifest arrives inside a start-points image the operator
supplies, so it is data rather than configuration, and a manifest that could ask
for a 4GB tmpfs is a way to exhaust a node. Two numbers therefore bound every
entry: the default, which is what an LTF gets by saying nothing, and a ceiling,
which is the most any LTF may have. The runner answers

    [ceiling, [default, manifest_ask].max].min

so an LTF can raise a limit but never past the ceiling, and a manifest asking
for less than the default gets the default: nothing an LTF says can make a kata
weaker than the common case.

runner.rb:106 already does the same arithmetic for max_seconds, taking the
minimum of RUN_SECONDS and the manifest's ask. The direction differs and the
shape does not: a limit the manifest may only tighten needs a min, and one it
may only loosen needs a max under a ceiling.

What it costs the pool. image_config(image_name) is a config that "depends on
the image alone, which is what lets it be made before the run it will serve is
known", and a limit read from the manifest is no longer image_name alone. A
manifest is per LTF and so is the image, so the two keys agree, but warming
would have to hold the manifest as well as the name. That is the one place this
key touches the pool, and it is why the key is step 12 rather than part of
step 4.

Where the outliers go. Julia and Elixir are the two the measurements name, and
each has three ways out before prod: a limits entry of its own, a change to the
start-point so it no longer needs one, or a global cap of zero, which turns the
pool off and leaves every test-run on the path it takes today.

### Why this line rather than dropping the daemon

docs/dropping-the-docker-daemon.md prices its own change at about 72ms, by
timing one kata through the daemon and through crun on one machine, on two hosts
that agreed on the difference. This pool is measured at about 84ms by
docs/profiling/where-the-traffic-light-time-goes.txt, against the 116.4ms a
test-run costs today.

So the pool saves more, and it does so with no OCI config to keep in step with
dockerd's, no seccomp profile shipped per architecture, no containerd client, no
extra capability in the runner container, and the isolation guarantee untouched:
one test-run, one container, nothing reused.

The fourth is the one to size first, because it decides how much memory is
left for the other three. It is also the one nobody chose: raising threads to
serve more test-runs at once raises it, and the containers that appear are
not idle ones at 12MB but working ones running a compiler.

A kata run is CPU work, so the number to size it against is cores. aws-prod
runs c5a.xlarge, 4 cores, and its load average is already about 4, with
learners getting a traffic-light inside 4 seconds and not timing out. That is
a machine at its working point: fully used, not oversubscribed.

So there is nothing to gain by admitting more work. config/puma.rb is two
workers of eight threads, sixteen in flight per task, which is above what the
cores can serve and is a backstop rather than a target. What makes runs faster
is making each one cheaper, which is what the pool does and what a faster
clock would do. Raising this number does the opposite: the queue moves out of
puma, where it waits, and into the cores, where everything slows at once.

### Fewer workers would mean fewer pools, and buys no throughput

Ten pools instead of one is the whole of the problem, so the obvious answer is
fewer workers. The runner waits on a socket rather than computing, and MRI
releases the GVL for that, so the concurrency lost to fewer workers should come
back from more threads.

Measured, by publishing the server's port and driving real /run_cyber_dojo_sh
requests at it, all for one image_name.

| puma                       | 8 at once | 16 at once |
|----------------------------|-----------|------------|
| Etc.nprocessors workers    | 285, 270  | 290        |
| 2 workers, 8 threads       | 273, 269  | 289        |

Milliseconds of batch wall-clock per run. Nothing to choose between them, and
at sixteen at once they are the same number.

That is the wrong measure, though, and it is worth saying why it looked
convincing. A batch's wall clock is total daemon work divided by how fast the
daemon gets through it, and the pool does not reduce that work: every test-run
still costs a create and a start, done by the warm afterwards rather than by
the run beforehand. Moved, not removed. A saturated daemon does not care when.

What a learner waits for is one request, so measure one request.

| pool | mean   | median | p90    |
|------|--------|--------|--------|
| 8    | 3386ms | 3519ms | 3961ms |
| 0    | 3566ms | 3682ms | 3973ms |

One worker, sixteen threads, sixteen requests at once, forty-eight of them.
The spare is worth about 180ms of mean and 160ms of median, which is close to
the 140ms the hit-versus-miss table predicts. The p90s are level, because the
tail is set by queueing for the daemon and the spare cannot help with that.

So the pool pays even when the daemon is the bottleneck, and it pays in the
only currency that matters: the wait between a learner pressing the button and
the traffic light arriving. What it does not do is raise how many test-runs the
node can serve in an hour.

Two pools instead of ten does raise the hit rate, about fivefold, and that is
arithmetic rather than measurement. What the throughput numbers say is only
that the extra hits do not raise throughput, which no arrangement of the pool
could. Whether they lower latency further, by turning misses into hits, is the
measurement that would justify rearranging puma, and it has not been made.

## Order

With 0 answered, the risk that is left sits in 1 to 3, which is where the
test-run changes shape. So 1 to 3 land together and stop there, with the whole
suite green against an inline create, start and exec and no pool behind it.
That is the intermediate stable point, and it is described above the steps
themselves.

Steps 4 to 8 are mechanical, and each is small only because that point exists
to build from: they move when a container is created without touching what a
test-run does with one.

Step 9 is the one that decides who can have this. Until the cap is settable,
the only safe number for a server on hardware nobody here has sized is zero, so
9 comes before the pool is turned on anywhere but aws-prod. It is also the only
step that changes another repo.

Step 11, the allowlist, belongs with step 9 and generalises it. An empty list is
the pool turned off, which is the safe default step 9 needs, and a list holding
python_pytest alone is the smallest thing that can be turned on and measured. So
the rollout is the list growing an image_name at a time with a hit rate read
between each, rather than a single decision about whether the pool is on.

python_pytest rather than another, for three reasons. It is among the LTFs the
server tests already depend on, so the suite exercises the allowlisted path
without a new fixture. Its image carries no compiler, so a spare of it costs the
smaller end of the memory range. And it is one of the LTFs most likely to be hot,
which is what a hit rate needs to be worth reading, though which LTFs are hottest
should come from press counts rather than from this file.

## Owed, and not part of any step

Both things this work turned up are now done.

SparePool#create reads the status the daemon answered, logs a failure, forgets
the image on a 404 and answers nil, and warm's thread declines to add a nil, so
nothing that is not a container reaches a queue.

NodeImages#forget tags its argument, as pull does before it looks in @pulled,
so both places state the keying that both depend on. No test pins it, and
deliberately: docs/profiling/check_tagged_alters_a_real_image_name.rb found that
tagged alters none of the 82 start-point image_names, so the two spellings
coincide for every name a test-run can arrive with. The invariant is real and
unreachable, which is a comment's job rather than a test's.

A third is done. Node has been folded into NodeImages, which is why config.ru
now reads

    context.images.seed

in place of a loop asking one class what the node holds and telling another to
believe it. Both were about the same question, which images this node has,
differing only in whether the answer came from the daemon or from memory, so
they were one question answered twice rather than a separation of concerns.
NodeImages#seed answers it, names_on_the_node does the reading, and Node,
node.rb, node_test.rb and context.node are gone.

Worth being clear that this was the opposite conclusion from the one about
NodeImages and SparePool above, and for a reason: those two sit on opposite
sides of a boundary, where these two did not.
