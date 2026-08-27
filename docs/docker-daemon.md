# context.docker is the docker daemon

`context.docker` answers a `DockerDaemon`: one method per endpoint the runner
uses on the daemon, over a `DockerSocket` that it is the only holder of.

    docker.image_names
    docker.pull_image(image_name)
    docker.create_container(config, name: container_name)
    docker.read_file(container_id, RAG_LAMBDA_FILENAME)

No caller assembles a docker URL, and `docs/docker-socket-privilege.md` reads
its endpoint table off this one class.

## What it decides, and what it does not

It answers `[code,body]`, as the transport does. Which code means what belongs
to whoever asked:

- `Node` raises, carrying what the daemon said instead of the image list
- `Puller` logs the code and the body, and leaves the image unpulled
- `TrafficLight` raises a `Fault` naming the image and the code
- `CyberDojoShRunner` raises `DaemonRefused` carrying the code, because a 404 to a
  create is the daemon saying the image is not on the node, which is what
  sends `Runner` back to the puller

Answering anything narrower than `[code,body]` would take those decisions away
from the only objects in a position to make them.

## A service, not an external

`Context` builds it alongside node, prober, puller and runner rather than in
`externals`. `@http` is the external: it is the object that opens the socket,
and this is the object that holds it. So `DockerDaemon` takes `context` in its
constructor the way the other services do, which is also what lets it reach
`@context.logger` the day it has something of its own to log.

Tests replace either seam. `set_context(docker:)` stands in for the whole
daemon, and `set_context(http:)` keeps the real URL-building and stands in for
the socket instead, which is what `docker_daemon_test.rb` does to pin every
endpoint.

## What the doubles no longer do

`DockerDaemonSpy` and `DockerDaemonStub` answer by endpoint name.
`DockerDaemonStub` cannot answer an image pull as a container create, and the
spy records `[:read_file, id, path]` rather than a path a test has to match a
substring of.

## The size of it

Eight endpoints in a service of this size, so the layer is thin, and it is worth
keeping only while something wants the list in one place. `CyberDojoShRunner`
holds one rather than living inside it: the run sequence, being create, attach,
start, stop and the deadline around them, reads in one piece where it is.
