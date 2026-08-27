# A missing image recovers only through Puller

Since the run path moved to the daemon socket, Puller is the only thing that
puts an image on a node. Nothing else pulls, and the daemon will not pull on
the runner's behalf. That is fine while Puller's bookkeeping is right, and
unrecoverable when it is not.

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

## What still recovers

runner.rb consults Puller on every test-run, not only at kata creation:

    return empty_result(:pulling, 'pulling', {}) unless
      puller.pull_image(id: id, image_name: image_name) == :pulled

So an image nobody has pulled does recover. The first test-run answers
"pulling" to the browser, a thread pulls, and a later press gets a traffic
light. That is the self-heal, and it is Puller's, not the daemon's.

## @pulled is seeded from the node, not from pulling

config.ru fills it before the first request:

    context.node.image_names.each do |image_name|
      context.puller.add(image_name)
    end

So most of what @pulled holds was never pulled by this process. It is a
snapshot of `docker image ls` taken when puma started, which on the machine
this was checked on was 176 names. Puma preloads, so the seed runs once in the
master and every forked worker starts from the same snapshot, then diverges as
each pulls on its own. That is why restarting is the current escape from the
stale state: the restart re-seeds.

It also means the stale window opens at boot rather than at the first pull.
Anything that removes an image after puma starts is invisible to @pulled.

The two paths agree on the key, which is worth knowing because they reach it
differently: config.ru adds the raw image-ls name, while pull_image tags the
manifest name through ::Docker.tagged_image_name. Checked against a real node's
176 names, tagging is the identity on all of them, and no start-point manifest
uses a digest, which is the form where the two would diverge.

One name did not survive tagging. node.rb filters the exact string
'<none>:<none>' but not a name like repo/name:<none>, where the repository is
set and the tag is not. tagged_image_name raises NoMethodError on that, its
regex having matched nothing. Such a name is nothing to do with cyber-dojo: it
is whatever else the host happens to have built.

Nothing hits it today, because puller.rb:20 is the only caller of
tagged_image_name and it tags manifest names, never seeded ones: the junk name
sits in @pulled and matches nothing. It stops being harmless as soon as
anything tags a seeded name, which is what the fix below would do. So the
filter in node.rb wants widening to any name whose tag is <none>, in the same
change.

## What does not recover

What does not recover is an image Puller believes is present and is not.
@pulled is add-only: puller.rb calls @pulled.add, never delete, though
SynchronizedSet#delete exists and @pulling uses it. Once an image name is in
there, pull_image answers :pulled forever. If the image then leaves the node,
every test-run for it does this:

  1. pull_image answers :pulled, so runner.rb goes on rather than pulling
  2. DaemonRun#create gets 404 and raises DaemonRefused
  3. runner.rb rescues it, logs, and answers faulty_result({})

There is no path out. Nothing re-pulls, because the only pull is gated behind
the cache that is wrong. The learner gets a faulty traffic light on every press
until that puma worker restarts, which is what empties @pulled.

## How an image leaves a node under Puller's feet

Not hypothetically. docs/purge-stale-images.txt plans exactly this: delete
images by age, driven off @pulled. Kubernetes does it too, without asking,
through kubelet image garbage collection. Either one produces the state above.

## The fix is pull-on-404, in the same place the CLI had it

Catch the 404 from create, POST /images/create, retry the create once. That is
the CLI's logic moved back in, and it is what makes a wrong @pulled survivable
rather than terminal: the create that 404s is proof the image has gone, so the
same handler can @pulled.delete(image_name) and let the eager path work
correctly from then on.

Note what this does not do. It does not make Puller redundant. Puller's job is
to pull at kata creation so the first test-run is fast, and pull-on-404 is a
recovery path for when that bookkeeping is wrong, on a run that is already
going to be slow. Both are wanted.

## Bearing on the other plans

docs/pre-started-container-pool.md gains a second caller of create, in a
background thread. A stale @pulled currently costs one visible faulty result
per press; with a pool it also costs a refill thread 404ing quietly for an
image that is gone. The pool wants the same invalidation, and its create is
another good place to notice the 404.

docs/dropping-the-dind-base-image.md converts Puller's `docker pull` to POST
/images/create. Whoever does that owns the streaming-progress error handling
this fix also needs, so the two belong in one change.
