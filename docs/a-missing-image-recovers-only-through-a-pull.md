# A missing image recovers only through a pull

Since the run path moved to the daemon socket, NodeImages is the only thing
that puts an image on a node. Nothing else pulls, and the daemon will not pull
on the runner's behalf. So every way an image can be missing has to end in a
pull, and what differs between them is how many faulty traffic lights it takes
to get there.

## The daemon does not pull

POST /containers/create answers 404 for an image the node does not have. It
takes a container config plus name and platform, and carries no pull-if-missing
option, so there is no flag to set. Probed against the daemon rather than read
from the docs, on Docker 29.7.2, API 1.55, 2026-08-27:

    curl --unix-socket /var/run/docker.sock --request POST \
      --header "Content-Type: application/json" \
      --data '{"Image":"cyberdojo/definitely-absent-image:nope"}' \
      http://localhost/containers/create

    {"message":"No such image: cyberdojo/definitely-absent-image:nope"}
    HTTP_CODE=404

`docker run` appears to pull because the CLI implements pull-on-404 itself,
client-side, and then retries the create. That logic lived in the CLI, so
running cyber-dojo.sh over the socket left it behind.

## An image nobody has pulled costs no faulty light

runner.rb consults the node's images on every test-run, not only at kata
creation:

    return empty_result(:pulling, 'pulling', {}) unless
      images.pull(id: id, image_name: image_name) == :pulled

So the first test-run answers "pulling" to the browser, a thread pulls, and a
later test-run gets a traffic light. That is the self-heal, and it is
NodeImages', not the daemon's.

## @pulled is seeded from the node, not from pulling

config.ru fills it before the first request:

    context.images.seed

So most of what @pulled holds was never pulled by this process. It is a
snapshot of `docker image ls` taken when puma started, which on the machine
this was checked on was 176 names. Puma preloads, so the seed runs once in the
master and every forked worker starts from the same snapshot, then diverges as
each pulls on its own.

It also means the stale window opens at boot rather than at the first pull.
Anything that removes an image after puma starts is invisible to @pulled.

The two paths agree on the key, which is worth knowing because they reach it
differently: config.ru adds the raw image-ls name, while pull tags the manifest
name through ::DockerImageName.tagged. Checked against a real node's 176 names,
tagging is the identity on all of them, and no start-point manifest uses a
digest, which is the form where the two would diverge.

`forget` is a third way in, and it tags exactly as pull does, so all three
places agree on the key by construction rather than by coincidence. The
coincidence holds anyway: runner.rb passes the raw manifest name, and
assert_versioned has already refused any manifest name without a tag, so
tagging such a name is the identity.
docs/profiling/check_tagged_alters_a_real_image_name.rb measures that over the
82 start-point names, none of which tagging alters, which is why no test can
tell the tagging from its absence.

One name did not survive tagging. names_on_the_node flattens RepoTags and
filters nothing, which is enough for a dangling image, the daemon answering
RepoTags as [] for one of those and 3q1Ps4 pinning that it contributes no name.
It is not enough for a name like repo/name:<none>, where the repository is set
and the tag is not: that arrives as a name like any other.
DockerImageName.tagged raises NoMethodError on it, its regex having matched
nothing. Such a name is nothing to do with cyber-dojo: it is whatever else the
host happens to have built.

Nothing hits it today, because node_images.rb's pull is the only caller of
DockerImageName.tagged and it tags manifest names, never seeded ones: the junk
name sits in @pulled and matches nothing. It stops being harmless as soon as
anything tags a seeded name. So names_on_the_node wants a filter for any name
whose tag is <none>, whenever that happens.

## An image that leaves the node costs one faulty light

An image @pulled believes is present and is not used to be terminal. The 404
from create is the only sign the runner gets that @pulled is wrong about the
node, so it is what acts on it:

  1. pull answers :pulled, so runner.rb goes on rather than pulling
  2. CyberDojoShRunner#create gets 404 and raises ImageMissing
  3. runner.rb rescues it, calls images.forget(image_name), answers faulty

The learner sees faulty once. The next test-run for that image finds @pulled no
longer holding it, so pull answers :pulling and the image comes back. Before
that, nothing re-pulled, because the only pull was gated behind the cache that
was wrong, and every test-run stayed faulty until the worker restarted.

ImageMissing is a class of its own rather than a status code the caller reads,
because a 404 to a container create says the image has gone while a 404 to an
exec create says the container has, and reading the second as the first throws
away an image that is present. K3nW8p and F7kR2m pin those two against each
other.

## How an image leaves a node under the runner's feet

Not hypothetically. docs/purge-stale-images.txt plans exactly this: delete
images by age, driven off @pulled. Kubernetes does it too, without asking,
through kubelet image garbage collection. Either one produces the state above.

## What is still missing: the retry

The CLI caught the 404, pulled, and retried the create inside the same run. The
runner invalidates but does not retry, which is why the cost is one faulty
light rather than none. The place for a retry is where the ImageMissing rescue
already is, and the streaming-progress error handling it needs is the handling
`NodeImages#stream_error?` already does, so that is where to start rather than
somewhere new. docs/dropping-the-dind-base-image.md records the two shapes a
pull's failures take.

Note what a retry would not replace. Pulling at kata creation is what makes the
first test-run fast; recovering from a wrong @pulled is a path for a run that is
already going to be slow. Both are wanted.

## The pool notices the 404 earlier than the run path

SparePool#warm, described in docs/pre-started-container-pool.md, is a second
caller of create, on a background thread. It reads the code that create
answered: a 404 logs the failure and forgets the image, and create answers nil,
which warm declines to start or add, so nothing that is not a container reaches
a queue.

That makes the pool the better of the two places to find out. A stale @pulled
costs one visible faulty light on the run path, because the run has already
been asked for by the time the 404 arrives. On the pool's path the 404 arrives
on a background thread before any learner has been shown anything, so the
belief is corrected at no cost to a test-run.
