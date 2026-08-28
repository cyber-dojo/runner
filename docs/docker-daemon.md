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
- `CyberDojoShRunner` raises `DaemonRefused` carrying the code, and raises the
  `ImageMissing` subclass of it for a 404 to a container create, that being
  the daemon saying the image is not on the node, which is what sends `Runner`
  back to the puller. A 404 to an exec create says the container has gone
  instead, and stays a plain `DaemonRefused`

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

## What keeps it thin

No method does anything: each builds one URL and hands back what the daemon
said. That is what thin means here, and it holds however many endpoints the
class grows, so the count is not the measure and is not worth maintaining in
prose. What would end the layer is nothing wanting the list in one place, and
`docs/docker-socket-privilege.md` wants it.

`CyberDojoShRunner` holds one rather than living inside it: the run sequence,
being create, start, the exec pair, stop and the deadline around them, reads in
one piece where it is.
