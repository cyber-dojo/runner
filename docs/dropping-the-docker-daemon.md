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

Four probes in `profiling/`, all aarch64 under Docker Desktop.

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
is copied, but this probe does not test that. It wants repeating on native amd64
Linux alongside `time_docker_run_split.sh` before the 86ms headline is trusted.

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

## The budget

| item | cost | source |
| --- | --- | --- |
| containerd snapshot prepare | free | the snapshot probe |
| overlay mount | 0.5 ms | the overlay probe |
| crun create+start+delete | 2.5 - 4.1 ms | time_oci_runtimes.sh, the overlay probe |
| Process.spawn from a puma worker | 0.4 - 0.6 ms | the spawn probe |
| config.json write | sub-ms | assumed, unmeasured |

Delete, umount and snapshot removal all come off the critical path, into the
reaper the design needs anyway. Against the 92ms it replaces, that is a saving
of roughly 80ms.

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
- Mount privilege. Applying the snapshot's mount needs CAP_SYS_ADMIN, so the
  deployment adds mount capability.
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

## Staging it

The risk is concentrated in the run plane. Almost everything else can land
against today's docker path, in an order where each step is releasable on its
own and none of the early ones changes what a learner sees.

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

The speedup arrives at step 7. The security benefit arrives at step 9, and not
before: through steps 1 to 8 the runner holds exactly the privilege it holds
today. So a restricted socket is what this plan ends with rather than a reason
to begin it, and any argument for starting has to rest on the latency alone.

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

## Open questions

- What `linux.maskedPaths` and `linux.readonlyPaths` should hold, the last of
  dockerd's invisible defaults still unstated. `check_test_run_confinement.rb`
  measured dockerd hiding `/proc/kcore` and `/proc/timer_list` by mounting
  /dev/null over them, so a kata run from this config would see the real files.
  Nothing may run from this config until this is answered, and step 4 is where
  the absence would otherwise be found by a test that passes.

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

  How many profiles that means is settled by the runner image rather than by
  seccomp. crun runs inside the runner container, so the arch that chooses the
  profile is the arch the runner sees. `cyberdojo/runner:latest` is a single
  manifest rather than a manifest list, so the image is published for amd64
  alone, and one profile is the whole set. An arm64 self-hoster runs the runner
  emulated today, and an emulated amd64 runner reports x86_64, so committing an
  `arm64.json` now would add a file nothing could ever select: support in
  appearance only, which is worse than none.

  Two profiles become right when the runner image is published for two
  platforms, which is the decision this actually turns on. It is also what a
  local test-run on arm64 against a CI run on amd64 would need.

  There is a reason to think that publishing has to come first rather than
  after. An emulated runner is fine under the docker path, because dockerd is
  native to the host and computes the boundary there. Under this design the
  emulated runner drives crun itself, with its mounts, cgroups and seccomp,
  through the emulation. Nothing here has tested that, and it should not be
  assumed to work.

  What a test-run meets today, with the runner published for amd64 alone. The
  language images are manifest lists carrying both arches, and dockerd is what
  pulls them, so a laptop gets an emulated runner driving a native kata:

  | Step | arm64 laptop | amd64 CI |
  | --- | --- | --- |
  | Host arch | arm64 | amd64 |
  | Runner image pulled | amd64 | amd64 |
  | Runner emulated | yes | no |
  | Language image pulled | arm64 | amd64 |
  | Kata emulated | no | no |

  And with the runner published for both, which is what makes a local run and a
  CI run differ in arch and in nothing else:

  | Step | arm64 laptop | amd64 CI |
  | --- | --- | --- |
  | Host arch | arm64 | amd64 |
  | Runner image pulled | arm64 | amd64 |
  | Runner emulated | no | no |
  | Profile the runner selects | `arm64.json` | `amd64.json` |
  | Language image pulled | arm64 | amd64 |
  | Kata emulated | no | no |

  Publishing the runner for both arches is worth doing on its own, before any
  of this, because it is what makes a measurement on a developer machine mean
  anything. A traffic light is timed in two halves, and on an arm64 machine they
  are currently in different states: the kata half runs native, since dockerd
  pulls the arm64 language image, while the runner half runs emulated, which
  `probe_lib.sh` records as about 72ms per test-run. Part native and part
  inflated is worse than uniformly wrong. A total is still comparable across the
  language images, since every one of them carries the same overhead, but a
  breakdown is not: the overhead lands on one half and changes the shape of the
  answer rather than scaling it.

  Under this design that gets worse before it gets better. An amd64 runner on an
  arm64 machine puts both halves under emulation. A runner published for both
  puts both halves back on the metal, and makes a laptop's numbers directly
  comparable with CI's as an arm64 against amd64 comparison rather than an
  emulation artifact.

  The row that changes hands is the language image. dockerd pulls it today, and
  dockerd is native to the host whatever the runner is, which is why the first
  table has a native kata under an emulated runner. Under this design the runner
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
