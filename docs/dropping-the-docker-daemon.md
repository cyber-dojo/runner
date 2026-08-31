# Dropping the docker daemon

Whether the runner can stop asking the docker daemon to run each test-run's
container, and drive an OCI runtime itself instead.

This is a design note plus four measurements. Nothing here is implemented.

Note what does and does not leave. dockerd leaves the test-run path. containerd
stays, and the recommended shape below depends on it staying.

## The idea

Today `cyber_dojo_sh_runner.rb` creates, attaches to, starts and stops one
container per test-run over the daemon's HTTP API on `/var/run/docker.sock`.

Instead, split the two planes and only bypass one of them.

- The image plane stays with containerd: pull, unpack, snapshot, and garbage
  collection. None of it is on the test-run path except one snapshot Prepare.
- The run plane bypasses dockerd and containerd's task service: build an OCI
  `config.json` over the snapshot's mount and `crun create/start/delete` it,
  with pipes wired straight to the container's stdio.

An earlier draft of this note proposed unpacking each image's rootfs into a
store of the runner's own and dropping containerd too. That is the wrong trade,
for reasons the Garbage collection and Measurements sections below give.

## Why it might be worth it

`../../faster-traffic-light.md` measures the container lifecycle at about 92ms
of a roughly 230ms fixed floor, split about 20ms create, 55ms start, 18ms
remove. It separately measures runc at 6226us and crun at 2532us for a whole
create+start+wait+delete over an already-unpacked bundle.

The gap between those is the point. Roughly 86ms of the 92ms is dockerd and
containerd orchestration -- container configuration, shim startup, event
handling, teardown -- wrapped around about 6ms of actual OCI runtime. A runner
that drives the runtime directly does not pay it.

The shim is the expensive part of that, not the snapshot. Which is what makes
keeping containerd for images compatible with removing the 86ms rather than in
tension with it.

`faster-traffic-light.md` reads its own crun-against-runc measurement as
"the OCI runtime is not the problem", which is true and is not this. That
comparison prices swapping one runtime for another. This prices removing what
sits above both of them.

## What that report now gets wrong

Three of its claims no longer match the code, and two of them matter here.

- It costs "the docker CLI, about 6ms per invocation" and proposes talking to
  the daemon's HTTP API instead. That is already done. `docker_daemon.rb`
  speaks HTTP on the unix socket and there is no CLI in the runner. So the CLI
  savings it lists, including the 88ms emulated figure in its decomposition,
  are already banked and are not available again.
- It quotes `config/puma.rb` as `workers(Etc.nprocessors)` times 5 threads
  times 3 replicas, up to 60 concurrent runs. The file is `workers(2)` and
  `threads(8, 8)`, so 16 per replica.
- Its finding 2 asks for admission control. `puma.rb`'s own comment argues for
  the thread cap as exactly that, with a worked table of 64 learners pressing
  [test] at once under 8 threads against 64. What is left unaddressed is that
  the cap is per process, so it multiplies by the replica count and nothing
  caps the node as a whole.

## Garbage collection, which is why containerd stays

Image tags are commit SHAs, so a rebuilt language image is a new image rather
than a replacement. The 88 images are today's count, not a bound: the node
accumulates a superseded image per LTF per rebuild, forever.

Nothing in the runner reaps them. `docker_daemon.rb`'s comment says its endpoint
list is complete, and it has no image removal at all. The only prune found
across these repos is `commander/app/server/clean.rb`, which is the manual
`cyber-dojo clean` CLI command and runs `docker system prune --force`. That
removes dangling images, and a superseded but still tagged
`java_junit:<old sha>` is not dangling, so it survives. Whether the ECS agent's
own image cleanup covers images the runner pulled rather than ones ECS pulled
for a task is unchecked here.

An OCI runtime cannot help with this. runc and crun have no concept of an image;
they run a bundle that something else prepared, so image lifecycle is not their
layer and there is nothing in them to reap it.

The layer that does have it is the layer being bypassed. containerd has
lease-based and label-based GC over its content store and snapshots. CRI-O and
the kubelet have disk-watermark eviction; podman and containers/storage have
refcounted layers and `prune --filter until=`. Any of those is a solved problem
that a hand-rolled rootfs store would have to reimplement, and the failure mode
of getting it wrong is a disk that fills quietly.

Keeping containerd also keeps its content store's deduplication of shared base
layers across the language images, which share a great deal.

## Measurements

Five probes in `profiling/`, on aarch64 under Docker Desktop. Two of them have
also run on native amd64, through
`.github/workflows/measure-probes-on-native-amd64.yml`, and where they have the
two hosts are given side by side.

### The snapshot round trip is free

`time_containerd_snapshot_prepare.sh` prices what the recommended shape adds to
the test-run path.

| span | mean |
| --- | --- |
| two ctr calls, the CLI floor | 5206 us |
| snapshot prepare + rm, floor included | 5215 us |

9us above a floor of two calls that do nothing, which this probe cannot
distinguish from noise. The 5.2ms in both rows is two `ctr` process startups,
which a runner speaking to containerd from its own process would not pay.

So the GC and the restricted socket proxy that containerd allows are not bought
with latency. That is the opposite of what was assumed before this ran.

Note that `prepare` answers the mount rather than performing it, so applying it
is still the caller's work, priced next. The snapshot here also has no parent,
so a real image's layers would give the mount more lowerdirs.

### Applying the mount costs about half a millisecond

`time_crun_on_overlay_vs_plain_rootfs.sh`.

| span | mean |
| --- | --- |
| overlay mount+umount, no container | 521 us |
| crun run, plain rootfs | 4143 us |
| crun run, overlay mount+umount included | 3795 us |

The lifecycle including the overlay came out below the one without it, a
negative difference and therefore below the probe's resolution rather than a
speedup. The reading is that filesystem preparation does not swallow the saving.

Caveats: one 20-iteration sample, both sides of the overlay on tmpfs, and a
small alpine rootfs. Mount cost should not scale with tree size, because nothing
is copied, but this probe does not test that.

Repeated on native amd64, by `.github/workflows/measure-probes-on-native-amd64.yml`
on a four-CPU runner, it reads differently:

| span | aarch64, Docker Desktop | native amd64 |
| --- | --- | --- |
| overlay mount+umount, no container | 521 us | 1526 us |
| crun run, plain rootfs | 4143 us | 7703 us |
| crun run, overlay included | 3795 us | 10709 us |

Every span is about twice as long there, so that host is slower rather than
faster and the columns are not a native-against-emulated comparison. What does
change is the reading of the third row against the second. Here the difference
was negative and so below the probe's resolution; there it is 3006us, half
again the mount measured alone. So "filesystem preparation does not swallow the
saving" holds, at 3ms against a docker lifecycle the same host priced at 164ms,
but the 0.5ms in the budget is this machine's figure and not a floor.

### Spawning from Ruby is a tax, not a floor

`time_spawn_against_ruby_heap_size.rb` finds `Process.spawn` proportional to the
parent's resident size, about 3.6us per MB with the collector disabled: 376us at
14 MB rising to 2115us at 491 MB. That is what copying page tables looks like.

The figure therefore belongs to the process making the spawn, not to the spawn.
Anything that grows a worker, such as 8 threads each holding a test-run's tgz
payloads, raises it. If it ever matters, execing from a small helper process
caps it at the 376us floor however large the worker gets. That is a contingency
rather than part of the design: nothing here measures a real worker's resident
size.

### A real kata, both paths, one machine

`time_kata_under_crun_vs_daemon.rb` sends the tgz the server tests send, first
through `CyberDojoShRunner` and then through crun from `CyberDojoShOciConfig`,
in one process on one machine. Ten runs of each, after a warm-up of each.

| span | aarch64, Docker Desktop | native amd64 |
| --- | --- | --- |
| crun, one kata | 36.5 ms | 65.0 ms |
| daemon, one kata | 108.5 ms | 137.1 ms |
| the difference | 72 ms | 72 ms |

About 72ms on both. The two hosts disagree on every absolute and agree on the
difference, which is the strongest form this result takes: what the change buys
survives a different arch, a different kernel and a different daemon version,
where neither column's own figure does.

It is also the first figure here taken from a kata rather than from
`/bin/true`, and it is close to what the decomposition above reaches by adding
up what dockerd does. Two routes to one number is a better reason to believe it
than either alone.

The amd64 column ran with crun's cgroup manager disabled, because crun cannot
write cgroups on that host, so its 65.0ms omits work the other column did and
its kata was held to neither limit. On this machine that omission is worth
about 2.7ms.

The two paths answered the same four files, `sandbox/cyber-dojo.sh`,
`tmp/status`, `tmp/stderr` and `tmp/stdout`, with the same contents, and the
same bytes on the container's own stderr. That agreement is what makes the pair
of timings mean anything: a faster path answering something else is not a
result.

What it does not price. The rootfs is unpacked once and reused, so no per-run
overlay is included; that is the probe above. The kata is one line of shell, so
neither column carries a real language's compile. And each column of the table
is a same-machine pair, which is the only kind that can be read this way: the
two hosts are compared on their difference and never on their absolutes.

## The budget

| item | cost | source |
| --- | --- | --- |
| containerd snapshot prepare | free | the snapshot probe |
| overlay mount | 0.5 ms | the overlay probe |
| crun create+start+delete | 2.5 - 4.1 ms | time_oci_runtimes.sh, the overlay probe |
| Process.spawn from a puma worker | 0.4 - 0.6 ms | the spawn probe |
| config.json write | sub-ms | assumed, unmeasured |
| the image's config | free once cached per image | see below |

Delete, umount and snapshot removal all come off the critical path, into the
reaper the design needs anyway. Against the 92ms it replaces, that is a saving
of roughly 80ms, which the kata probe above independently measures at 72ms by
running one both ways rather than by adding these rows up.

### The image's config is read once per image, not once per run

Two fields of a language image's own config reach a bundle, and dockerd supplies
both without being asked, which is why nothing in the runner names them today.

- `Env`, which is where PATH comes from. `process.env` is the whole environment
  an OCI runtime gives a process, so a config naming only the run's three
  entries starts a process that cannot find bash.
- `WorkingDir`, which is where dockerd starts a container. The perl image
  declares `/usr/src/app`, so a bundle defaulting `process.cwd` to `/` starts a
  kata somewhere dockerd would not.

`profiling/check_crun_run_from_oci_config.rb` is where both were found, and one
image read answers both, so they are one cache rather than two.

Resolving that read per test-run puts a round trip on the critical path this
budget would otherwise not carry, and it does not have to. A tag here is a
commit sha and is never pushed twice, so an image's config cannot change under
the name the runner holds. The cache therefore needs no invalidation at all,
rather than needing one that is left out.

This needs no new scheme: `traffic_light.rb`'s `source_from_image` already reads
the red-amber-green lambda out of an image and keeps it per image for exactly
this reason, in a `Concurrent::Map` keyed by image name.

Nothing measures the round trip. What this row prices is the decision to cache,
so the cost of not caching is unstated rather than small.

## What it needs installed

sinatra-base stays as the base image. It is `ruby:4.0.5-alpine3.24`, and
Alpine 3.24 packages what is needed:

| package | version | size |
| --- | --- | --- |
| crun | 1.28 | 523 KiB |
| tini | 0.19.0 | already installed by sinatra-base |

`crun` is the only addition. skopeo and umoci, which an earlier draft needed,
are not: containerd pulls and unpacks.

Root is not a new requirement: `runner/Dockerfile` already sets `USER root` for
the socket. `Init` has no OCI equivalent, so tini moves into the bundle's
`process.args`; sinatra-base already provides it at `/sbin/tini`.

## What changes in the Ruby

Every endpoint on `DockerDaemon` has a replacement, across three call sites.

| call site | today | instead |
| --- | --- | --- |
| `cyber_dojo_sh_runner.rb` | create, attach, start, stop | snapshot prepare, then crun with pipes |
| `traffic_light.rb:103-122` | create, read_file, remove | read the file from a view snapshot's mount |
| `node_images.rb:66,79` | image_names, pull_image | containerd's images service |

`traffic_light.rb` is a bonus rather than a cost: it creates a container purely
to read `red_amber_green.rb` out of an image and then removes it, which becomes
a file read over a read-only snapshot. That removes a container from the path of
the 12 start-points that carry no `rag_lambda`.

Deleted: `externals/docker_socket.rb`, `docker_daemon.rb`,
`docker_attach_frames.rb`, and `Context`'s `:http` external. Attach frame
demultiplexing is a docker protocol artifact; a runtime driven directly gives
real pipes. `context.rb` already records that `DockerDaemon` is the sole holder
of `@http`, and a grep for `.http` confirms one consumer.

Kept: `deadline_reader.rb`. The read on the payload pipe still needs bounding.

Added: an external that execs crun, and a containerd client. The test seam does
not change, because `Context`'s options hash swaps both exactly as it swaps
`:http` today.

`CyberDojoShContainerConfig` and `CyberDojoShHostConfig` map onto an OCI
`config.json` field for field: `process.user`, `process.args`, `process.env`,
mounts for the two tmpfs, `linux.resources` for memory and pids,
`linux.rlimits` for the seven ulimits, `noNewPrivileges`, `SYS_PTRACE` for the
clang images, and an empty network namespace for `NetworkMode: none`. `Init` and
`AutoRemove` are the two entries with no OCI equivalent.

That mapping is complete for what those two files say. It is what they do not
say that the next section is about.

## The defaults that are currently invisible

This is the strongest argument against the design, and it is not about latency.

The boundary that matters in the runner is the node against code a learner
submitted. Today dockerd enforces part of that boundary through defaults which
appear nowhere in `CyberDojoShHostConfig`. That file sets no-new-privileges, a
pids limit, a memory limit, seven ulimits, `NetworkMode: none`, the sandbox
user, and `SYS_PTRACE` for the clang images. Everything it does not set is
dockerd's default, and it is invisible precisely because nothing had to ask for
it.

Two of those defaults matter, and they are not the same size.

- Seccomp is the real gap. dockerd applies a default seccomp profile to every
  container it runs. `runc spec` emits no seccomp section at all, so a bundle
  built from it runs with the host's full syscall surface. Nothing in the
  config classes above would notice, because seccomp was never theirs to set.
- Capabilities are the smaller worry. `runc spec`'s generated default is a
  narrow set, narrower than dockerd's default drop. So this is likely not a
  regression, but it becomes a default being relied on rather than a decision
  the runner states.

What makes seccomp dangerous here is not that it is hard. It is that losing it
changes nothing observable: every start-point still goes green, every test still
passes, and the sandbox is simply weaker than it was. A missing protection has
no failing test, which is the opposite of every other risk in this note.

So the config classes have to grow a seccomp profile of their own, explicitly,
and it has to be reviewed as a security artifact rather than generated once and
forgotten. Whether the right profile is a copy of dockerd's default, or a
narrower one written for what a kata legitimately does, is unresolved and
deliberately left open.

Not assessed here: whether apparmor or SELinux contributes anything on the
production host, which would be a third default in the same category.

## What it costs

- A containerd client in Ruby. containerd's API is gRPC, which means the grpc
  gem and stubs generated from containerd's protos, where the runner today
  needs neither. The fallback is shelling out to `ctr`, and the snapshot probe
  prices that at about 2.6ms per invocation, which is affordable for pulls but
  is most of a per-test-run snapshot's budget. Which route to take is open.
- Privilege in the runner container, which is more than mount capability.
  `profiling/check_crun_run_from_oci_config.rb` ran a container from the OCI
  config and hit one refusal at a time: CAP_SYS_ADMIN, without which `clone`
  will not make the namespaces; CAP_NET_ADMIN, without which the loopback
  interface cannot be brought up; a writable `/sys/fs/cgroup`, without which the
  memory and pids limits cannot be applied; a bundle on a mount of its own,
  since `pivot_root` refuses a new root on the mount it is already on; and an
  outer seccomp profile that permits `pivot_root`, which dockerd's default
  refuses. crun also wants `--no-new-keyring`, because dockerd's profile refuses
  the runner `keyctl`. Each was found by a run rather than reasoned about, so the
  list is what a deployment has to grant rather than a guess at it.
- The socket changes rather than disappears, and improves.
  `docker-socket-privilege.md` explains why a proxy does not help today: the
  runner needs container create with an arbitrary config, and a create with a
  host bind mount owns the node. Under this shape the runner never asks anything
  to run a container, so a proxy restricted to the images, content and snapshots
  services is viable. The containerd socket is still root-equivalent handed over
  whole, so the proxy is the point rather than the switch.
- Container lifetime becomes the runner's. `AutoRemove` is the daemon's job
  today; a crashed puma worker would leak a container, its mount and its
  snapshot, so the design needs a reaper.
- Images stop appearing in `docker image ls`. They appear in
  `ctr images ls` instead, so this is a change to operator habits rather than a
  loss.

dockerd itself stays on the node: ECS still runs the service containers through
it. What changes is that it leaves the traffic-light critical path.

## What a containerd proxy would have to allow

The counterpart of the endpoint table in `docker-socket-privilege.md`, written
before anything enforces it, so that the privilege being asked for is stated
rather than discovered at step 9.

| Service | What the runner asks of it |
| --- | --- |
| images | resolve an image reference, and pull one that the node lacks |
| content | read and write the blobs a pull produces |
| snapshots | prepare the rootfs for one test-run, and remove it after |
| leases | hold what a run is using, so the garbage collector leaves it |

What is absent is the point. There is no containers service and no tasks
service, because the runner never asks containerd to run anything: it execs
crun against a bundle itself. A proxy allowing the four above refuses the two
that create and start containers, which is the pair that makes the socket
root-equivalent today.

This is service granularity, which is where step 9 draws its line. The method
names within each service are not written here because nothing has checked them
against the containerd version the deployed host runs.

## What the proxy does not remove

The proxy above refuses the two services that create and start containers, which
is what makes today's socket root-equivalent. It does not follow that the runner
stops being able to create a container with any config it likes.

After step 9 the runner still holds CAP_SYS_ADMIN and still writes the
`config.json` it hands crun. Mounts in an OCI config are arbitrary, so those two
together are "create a container with any config": bind the host's root into a
bundle, run it as uid 0, and the node is yours. That is the same escape the
proxy exists to refuse, reached without asking anything to run a container.

So step 9 relocates that escape rather than removing it. It moves from a socket,
where a proxy can police it, to a local binary, where nothing does. "The
security benefit arrives at step 9" is therefore weaker than it reads: what
arrives at step 9 is a much smaller socket, four services with no create body to
judge, and not the end of the arbitrary-config problem.

Two things would close it, and both make a non-root runner mean something, which
`docker-socket-privilege.md` correctly says it does not mean today.

- Rootless crun with a user namespace. No CAP_SYS_ADMIN anywhere, so the
  arbitrary mount is refused by the kernel rather than by policy: the runner is
  root only over its own mapped uids. This is the one route where dropping the
  uid is itself the protection. It needs cgroup v2 delegation for the memory and
  pids limits, and `profiling/check_test_run_confinement.rb` measured that
  dockerd shares its user namespace rather than making one, so this is a change
  in behaviour rather than a translation of today's.
- A small privileged helper that owns config generation. It takes an image name
  and a run id, builds the config itself, and accepts no mounts from its caller.
  The Ruby worker runs unprivileged and cannot ask for a bundle that reaches the
  host. File capabilities on that helper keep the privilege in it rather than in
  the worker, which needs the runner container not to set no-new-privileges on
  itself, since that is exactly what stops a binary gaining privilege on exec.

The second is cheap rather than elaborate, for the reason the next section
gives: there is almost nothing per run for a caller to influence.

## A config per image, not per test-run

Field by field, a test-run's OCI config barely varies.

| varies | fields |
| --- | --- |
| per run | `CYBER_DOJO_ID` in `process.env`, and `root.path` |
| per image | the capability set, the rlimits, which seccomp file is read, `CYBER_DOJO_IMAGE_NAME`, and `process.cwd` from the image's `WorkingDir` |
| never | the command, the sandbox uid and gid, the three mounts, the memory and pids limits, the namespaces, the masked and read-only paths, `noNewPrivileges`, `ociVersion` |

Every per-image field turns on one predicate,
`CyberDojoShHostConfig.added_capabilities`, so in practice there are two shapes:
an ordinary image, and a clang image with CAP_SYS_PTRACE.

Three things follow.

The budget's "config.json write, sub-ms, assumed" can become a cached template
and two substitutions. crun reads a file, so the write stays; building and
serialising the structure need not happen per run.

The helper above becomes easy to make safe. With only an id and a rootfs path
left for a caller to supply, there is no field through which to ask for a bind
mount of the host. The escape closes because the variability is genuinely tiny,
not because the helper validates cleverly.

And caching a config per image is caching a security artifact per image, which
is worth saying out loud. Keyed by image name it is as sound as the image config
cache, for the same reason: a tag is a commit sha and is never pushed twice. A
stale boundary would be a worse failure than a stale PATH, so what makes it safe
should not be left implicit.

## Staging it

The risk is concentrated in the run plane. Almost everything else can land
against today's docker path, in an order where each step is releasable on its
own and none of the early ones changes what a learner sees.

Steps 1, 2, 3 and 5 have landed. Step 4 has not, and the next piece of work is
not step 4: see "Where this has got to" below.

1. Capture the baseline. Run the capability and seccomp probe against the
   current docker path and record what the kernel actually applies: the
   `CapBnd`, `CapEff` and `CapAmb` masks from `/proc/1/status` inside a real
   test-run container, `NoNewPrivs`, the `Seccomp` mode and the filter count,
   and the results of attempting the syscalls dockerd's default profile blocks.
   Nothing can be proved equivalent later without this, and it has to be taken
   while dockerd is still the thing running the container.
2. Name the seam. `CyberDojoShRunner` reaches for `@context.docker` directly.
   Introduce a contract of its own, answering the payload for one
   cyber-dojo.sh, with `DockerDaemon` behind it. A pure refactor with no
   behaviour change, and it is where a crun implementation later slots in.
3. Emit an OCI `config.json` alongside, unused. Generate it from the same source
   as `CyberDojoShContainerConfig`, and test that both express the same limits.
   Nothing runs it, so the field-for-field mapping is de-risked without
   production seeing any of it. It covers only what the two config classes say,
   which leaves out `process.capabilities` and the seccomp profile: those are
   dockerd defaults, and choosing them is the open question below rather than a
   translation. Write the containerd endpoint list here too, the way
   `docker_daemon.rb` already keeps one for dockerd, so what a proxy would have
   to allow is stated long before anything enforces it.
4. Dual-run in the test suite. The server tests already drive real containers,
   so run a set of katas through both paths and assert identical colours and
   files, with the step 1 probe as a gate on the new path being no weaker. This
   is where crun first executes anything, and it does so in CI.
5. Give runner a manual deploy workflow, so a chosen image can be deployed and
   an earlier one put back. See "The deploy workflow" below. This has no
   dependency on anything above it and is worth having on its own.
6. Deploy to aws-beta and measure there. Beta is the same ECS architecture,
   possibly on a smaller instance, so it answers whether the design works and
   roughly what it wins, on real infrastructure rather than a laptop.
7. Deploy to aws-prod, keeping the docker path in the code as the thing an
   earlier image still contains.
8. Retire the docker path, once step 7 has held. Until this lands the runner
   still mounts the full docker socket, because rolling back to an earlier
   image needs it. The step 2 seam goes with it: one implementation left is
   nothing to choose between, so `Runner` holds that one directly and `Context`
   carries a single runner again. The seam is what makes the switch possible
   rather than something the finished design keeps.
9. Put a proxy in front of the containerd socket, restricted to the images,
   content, snapshots and leases services, and drop the direct socket mount.

The speedup arrives at step 7. Through steps 1 to 8 the runner holds at least
the privilege it holds today, and by the measurements in "What it costs" rather
more. Step 9 is what reduces the socket, and "What the proxy does not remove"
says what it leaves behind, which is not nothing. So a restricted socket is what
this plan ends with rather than a reason to begin it, and any argument for
starting has to rest on the latency alone.

### Falling back means deploying an earlier image

Not a runtime branch. The tempting version is to catch a crun failure and run
that test-run through docker instead, and it should not be built: a container
that runs with a weaker sandbox still answers a green light, so a per-test-run
catch would swallow exactly the evidence that matters while reporting success.

Rollback is therefore the step 5 workflow, redeploying the previous image.

### Measuring on beta

Web's `@duration` spans the same window the runner measures, so the comparison
needs no new instrumentation. Alongside it, the `faulty_result` and
`corrupt_payload` counts are what a mis-mapped config or a broken bundle would
surface as.

What beta cannot give is a side-by-side comparison. ECS runs one task definition
per service, so the two paths cannot run as different replicas of the same
service, and prod is not somewhere to experiment. The comparison is therefore
before and after on beta, which only means anything if the load is the same both
times. Beta has little organic traffic, so that load has to be driven
deliberately rather than waited for.

### The deploy workflow

runner has no way to deploy or roll back a chosen image. differ does, in
`.github/workflows/deploy-manually-to-aws-beta.yml` and its aws-prod sibling,
and everything that file needs already exists here: `deployment/terraform/`
with both tfvars, and `flow-templates/kosli-apply.yml`. Its `SERVICE_NAME`
derives from the repository name, so that line needs no edit at all.

It is a `workflow_dispatch` taking an image tag and an image digest, and it
pins `TF_VAR_TAGGED_IMAGE` to both. So putting an earlier image back is the
same dispatch with the earlier pair, and what comes back is exactly what ran
before rather than whatever a tag now points at.

`AWS_ECR_ID`, `AWS_REGION` and `AWS_ACCOUNT_ID_BETA` are already used by
`main.yml`, and `tf_version: v1.14.9`, `working_directory`,
`flow-templates/kosli-apply.yml` and the `gh_actions_services` role all match
what its existing beta deploy uses. `cyber-dojo/runner` is on the
`gh_actions_services` OIDC trust list in `terraform-base-infra/iam.tf`.
Unchecked: whether `AWS_ACCOUNT_ID_PROD` is set for runner, since `main.yml`
only ever names the beta one.

#### The terraform goes back with the image

`kosli-dev/tf/.github/workflows/apply.yml` takes a `ref` input, a branch, tag or
SHA, and hands it to `actions/checkout` alongside an explicit `repository`. Left
unset it checks out the repository's default branch, which is what differ's pair
does, so a rollback there would run today's terraform against an old image. That
pairing has never run anywhere, and an environment several deployments behind is
exactly when someone reaches for a rollback.

runner's pair passes `ref: ${{ inputs.image_tag }}`, so the terraform applied is
the terraform of the commit the image was built from. Putting an earlier image
back puts its infrastructure back with it, which is what makes this a revert
rather than a redeploy of one half.

Note this needs nothing of the old commit but its terraform. The workflow itself
runs from the default branch and only checks the older ref out, so it works for
images built long before these files existed.

The same input answers a question this repo does not need yet:
`github_repository_to_checkout` exists, in its own words, for when "a workflow in
one repository needs to operate on a different repository's Terraform code". So
a single deploy workflow serving every service is expressible. What stands in the
way is not the tf workflow but the `gh_actions_services` OIDC trust list in
`terraform-base-infra/iam.tf`, which names repositories individually.
`cyber-dojo/aws-prod-co-promotion` is already on it, which is the model for such
a thing: a dedicated deployment repository rather than
`reusable-actions-workflows`, whose `@main` every service already consumes and
whose blast radius should not grow to include deploying them.

Steps 1 to 3 are worth having even if the rest is abandoned, which is the test
this staging is built around. Step 1 documents a boundary the runner currently
relies on without stating, and step 2 is a seam worth having whatever ends up
behind it.

One thing deliberately not staged this way: moving images to containerd while
still running containers through dockerd. It looks like the garbage collection
win for none of the run-plane risk, but it means two image stores unless dockerd
is switched to the containerd image store, and whether that is available on the
production daemon is unchecked.

## Where this has got to

| Step | State |
| --- | --- |
| 1. Capture the baseline | done, `docs/profiling/check_test_run_confinement.rb` |
| 2. Name the seam | done, `Context`'s `:test_run` |
| 3. Emit an OCI config, unused | done, `CyberDojoShOciConfig` |
| 3.5 State the boundary dockerd implies | capabilities, namespaces, seccomp and the proc paths done; the per-CPU thermal_throttle mask not |
| 4. Dual-run in the test suite | not started; needs crun, and a rootfs to run it over |
| 5. Manual deploy workflow | done, ahead of the rest, as its own note says |
| 6 to 9 | not started |

Step 3.5 is not in the list above because it was not foreseen. Step 3 stopped
where the two config classes stop, which left `CyberDojoShOciConfig` stating no
capabilities, no seccomp profile and one namespace, and step 4 cannot run a kata
from a config like that: its own gate, the step 1 probe, would correctly fail
it. So the boundary dockerd applies had to be measured and written down first.
Capabilities, namespaces, seccomp, `linux.maskedPaths` and
`linux.readonlyPaths` now are. The paths come from moby's fixed lists in
`daemon/pkg/oci/defaults.go`, which `k7Rm24` and `k7Rm23` assert. What is not
stated is the one mask dockerd computes rather than declares: a
`/sys/devices/system/cpu/cpu<n>/thermal_throttle` entry per CPU the node has.

The next piece of work is not step 4. It is arch, and it splits into two pieces
that do not depend on each other.

The first is local. A developer's `make image_server` should build for the
machine it runs on, arm64 on an arm64 laptop and amd64 on a linux box, with the
katas of a test-run matching. It does not. `linux/amd64` is pinned in eight
places: the three services in `docker-compose.yml`, the COMMIT_SHA check in
`bin/build_image.sh`, and four pulls and runs in `bin/setup_dependent_images.sh`.
So an arm64 laptop builds an emulated amd64 runner and pulls amd64 katas beneath
it. Removing those pins is what makes an `arm64.json` selectable at all, and
what makes a measurement taken on a laptop mean anything.

The five language images the suite names, in `test/dependent_display_names.rb`,
allow it. `clang_assert`, `gcc_assert`, `perl_test_simple` and `python_pytest`
are manifest lists carrying amd64 and arm64, so the pin rather than the manifest
is why `clang_assert:ed23233` reports `x86_64` on an arm64 machine.
`cyberdojofoundation/visual_basic_nunit:003c9f0`, which the client tests use, is
a single amd64 manifest, so that one kata is emulated on an arm64 laptop
whatever the pins say.

The second piece is publishing the runner image for both arches, for the three
reasons the last open question gives: a sandbox installed by an emulated crun is
not one to trust, self-hosted servers run on arches this repo does not publish
for, and a measurement taken on an arm64 developer machine is part native and
part emulated. This one is not local to the runner. The published image is built
by `secure-docker-build.yml` in `cyber-dojo/reusable-actions-workflows`, which
every service consumes at `@main`, and which passes no `platforms` to
`docker/build-push-action@v7` and so builds the CI runner's own arch alone.

sinatra-base did not extend that workflow. It moved its build into its own
`main.yml` with `platforms: linux/amd64,linux/arm64`, and two things it met are
what a shared workflow would have to answer. A multi-platform result cannot be
loaded into a docker image store, so the tar that `secure-docker-build.yml`
saves and uploads, and that runner's `main.yml` downloads for its test jobs,
carries one platform rather than the index. And its SBOM step reads
`{{ json .SBOM.SPDX }}` from `imagetools inspect`, whose shape against an index
is unchecked here.

Publishing amd64 alone is not a deployment problem meanwhile. The ECS nodes are
amd64, so a single-arch image and a profile chosen by the runner's own arch
agree. "Builds for arm64" and "passes its own suite on arm64" stay separate
claims.

One loose thread. The programs that time a red, amber and green run across all
88 language images were not found while writing this, so whether they drive the
runner's HTTP API or shell out to docker was never established. That decides
whether they carry the runner's emulation overhead at all.

## Open questions

- How the runner arrives at the per-CPU `thermal_throttle` masks. moby stats
  `/sys/devices/system/cpu/cpu<n>/thermal_throttle` for every possible CPU and
  masks the ones that exist, computed once as the daemon starts, for the
  side-channel in advisory GHSA-6fw5-f8r9-fgfm. dockerd reads the node it runs
  on; the runner would read its own container's `/sys`, and whether those two
  see the same CPUs is unchecked. Until this is answered a kata run from this
  config can read a path dockerd masks, so what this gates is a question of its
  own: a dual-run in the test suite runs our own katas, where a deployment runs
  a learner's code.

- Whether a shipped seccomp profile can serve every node cyber-dojo runs on.
  This is the strongest form of the invisible-defaults argument, and it is not
  about cyber-dojo.org.

  Today the boundary is portable for free: each operator's dockerd computes it
  for that operator's node. A server started by the `cyber-dojo` script in the
  commander repo gets a boundary suited to whatever it runs on, and nobody had
  to say so. Under this design the runner ships the boundary instead, and a
  shipped boundary is right for the machines it was generated on and wrong for
  the rest.

  Two of the three axes turn out not to vary. Capabilities and namespaces are
  the same whatever the kernel. Of the syscalls, exactly one block carries a
  `minKernel`, gating `process_vm_readv`, `process_vm_writev` and `ptrace` at
  4.8, which is 2016, and which every plausible node clears. So the kernel is
  not the problem it first looked like.

  The arch is. `seccomp_linux.go` takes `goToNative[runtime.GOARCH]`, the arch
  of the daemon process, so dockerd applies its own host's profile to every
  container whatever the image is, emulated or not. A profile naming
  `SCMP_ARCH_X86_64` is wrong on an arm64 self-hoster, and
  `source/server/seccomp/` holds amd64 alone. So the selection has to be by the
  arch the runner runs on, read once, which is what dockerd does; and one
  profile has to exist per arch cyber-dojo supports, each generated on that arch,
  because the generator reads its own `runtime.GOARCH`.

  Not the arch of the image, which is a tempting mistake twice over. dockerd
  does not consult it, and the profile is part of the create, so nothing has run
  yet to be asked. A multi-arch tag does not reach this decision either: it
  resolves to one image at pull, and `NodeImages` pulls before the create.

  crun runs inside the runner container, so the arch that chooses the profile is
  the arch the runner sees. amd64 and arm64 are the two arches supported, so two
  profiles are the whole set.

  A host-native `make image_server` is what makes `arm64.json` selectable, and a
  developer laptop is where it is first chosen and first exercised. That is why
  the local build comes before the published one. Until the published image
  carries both arches, CI and the ECS nodes choose `amd64.json` because they are
  amd64, and an arm64 self-hoster chooses it too, because the emulated amd64
  runner it is left with reports x86_64. That last case is the one the
  emulation concern below is about rather than one this supports.

  There is a reason to think that publishing has to come first rather than
  after. An emulated runner is fine under the docker path, because dockerd is
  native to the host and computes the boundary there. Under this design the
  emulated runner drives crun itself, with its mounts, cgroups and seccomp,
  through the emulation. Nothing here has tested that, and it should not be
  assumed to work.

  What a suite test-run meets today. The language images are manifest lists
  carrying both arches, but `setup_dependent_images.sh` pulls them for amd64, so
  a laptop runs both halves emulated:

  | Step | arm64 laptop | amd64 CI |
  | --- | --- | --- |
  | Host arch | arm64 | amd64 |
  | Runner image built for | amd64 | amd64 |
  | Runner emulated | yes | no |
  | Language image pulled | amd64 | amd64 |
  | Kata emulated | yes | no |

  And with the pins removed, which is what makes a local run and a CI run differ
  in arch and in nothing else:

  | Step | arm64 laptop | amd64 CI |
  | --- | --- | --- |
  | Host arch | arm64 | amd64 |
  | Runner image built for | arm64 | amd64 |
  | Runner emulated | no | no |
  | Profile the runner selects | `arm64.json` | `amd64.json` |
  | Language image pulled | arm64 | amd64 |
  | Kata emulated | no | no |

  The last two rows hold for every language image the suite names except
  `visual_basic_nunit`, which publishes amd64 alone and so stays an emulated
  kata on an arm64 laptop.

  Building the runner host-native is worth doing on its own, before any of this,
  because it is what makes a measurement on a developer machine mean anything. A
  traffic light is timed in two halves, and a probe on an arm64 machine has them
  in different states: `probe_lib.sh` pins no platform, so its kata half runs
  native on the arm64 language image, while the runner half is the amd64 image
  the pinned build produced and runs emulated, at about 72ms per test-run. Part
  native and part inflated is worse than uniformly wrong. A total is still
  comparable across the language images, since every one of them carries the
  same overhead, but a breakdown is not: the overhead lands on one half and
  changes the shape of the answer rather than scaling it.

  Under this design an amd64 runner on an arm64 machine puts both halves under
  emulation. A host-native runner puts both halves back on the metal, and makes
  a laptop's numbers directly comparable with CI's as an arm64 against amd64
  comparison rather than an emulation artifact.

  The row that changes hands is the language image. dockerd pulls it today, and
  dockerd is native to the host whatever the runner is, so an unpinned pull
  gives a native kata under an emulated runner, which is what a probe meets and
  what the suite would meet if it did not pin. Under this design the runner
  pulls it through its own containerd client, so the runner picks the platform,
  and an emulated amd64 runner asking for what it is would get an emulated kata
  as well. Which platform to ask for is a decision this design adds and the
  current one never had to make.

  The third axis is the version. What is committed came from `moby/profiles`
  main, and what a node enforces is the profile compiled into that node's
  dockerd. The two drift apart on their own, and a profile that has drifted
  still runs and still passes every test while allowing a kata something the
  daemon beside it would refuse. `resolve_seccomp_profile.go` records the
  version, the platform and the kernel that produced each committed file, which
  is enough to regenerate but not enough to notice. What would notice is
  running `check_test_run_confinement.rb` on an aws-beta node, which has not
  been done: every measurement behind these files was taken on a developer
  machine under Docker Desktop.
- Which containerd client to use from Ruby, per the first cost above. This is
  now the largest unknown in the design.
- A real runner worker's resident size, which is what turns the spawn probe's
  slope into a figure. The 0.4-0.6 ms in the budget assumes the low end of a
  range this repo has not measured.
- Whether the overlay figure holds for a large language image on native amd64,
  where a real image's layers give the mount many more lowerdirs than the
  parentless snapshot measured here.

Two questions an earlier draft carried are answered by the shape above rather
than still open. Garbage collection of superseded images is containerd's, not
something to build. And where the overlay's upperdir lives is decided by where
containerd's root is, which is on disk, so a test-run's writes are charged to
the volume as they are today rather than to the RAM the earlier draft's tmpfs
upperdir would have used.
