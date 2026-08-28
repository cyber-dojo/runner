# The runner needs the docker socket, not a docker CLI

The runner's image is built `FROM ghcr.io/cyber-dojo/sinatra-base`, the same as
saver and the other services. It carries no `docker` CLI binary. Everything it
asks of the daemon travels over the socket instead.

## Why the daemon socket is not the obstacle

The runner does not run a docker daemon of its own. It talks to the host's
daemon through the socket bind-mounted by `docker-compose.yml`:

    - /var/run/docker.sock:/var/run/docker.sock

That mount is a compose / task-definition concern. It works regardless of which
base image the runner is built from, because opening a unix socket needs no
docker binaries at all: `source/server/externals/docker_socket.rb` speaks
HTTP over the socket directly.

So "runner needs the docker socket" and "runner needs a dind base image" are
separate claims, and only the first is true.

## How the runner drives the daemon

No `Open3.capture3` runs on a request path. Three routes carry what the daemon
is asked for:

| Purpose | Endpoint |
| --- | --- |
| list images | `GET /images/json`, flattening `RepoTags` |
| pull an image | `POST /images/create?fromImage=<name>` |
| read one file out of an image | create, `GET /containers/{id}/archive`, delete |

A pull is `POST /images/create?fromImage=<name>`, the tag riding inside
`fromImage` so nothing has to split the name apart. Failure has two shapes: the
daemon resolves the reference before it answers, so a name no registry can serve
is a plain 404 carrying `{"message":...}`, while a transfer that fails after the
200 says so with an `error` object in the stream. `NodeImages#stream_error?`
reads the second. The 404 half is probed both ways, unknown repository and tag
on a known repository, and `node_images_test.rb:9j5t9S` pulls for real. The
in-stream half is docker's documented behaviour and is not something this repo
has reproduced, which `9j5t9R` says of itself in a comment; forcing a transfer
to fail mid-stream needs a registry that misbehaves on purpose.

`DockerSocket#request` writes a fixed set of headers and takes no argument for
more, so there is nowhere to put the `X-Registry-Auth` that a private registry
wants. That absence is deliberate rather than merely tolerable. cyber-dojo.org
runs public images only. The people who run their own servers, under plain
docker via commander, are the ones who might want a private image, and what is
asked of them is that they pull it onto the host before bringing the server up.
config.ru then seeds NodeImages from the node's images, so an image already on
the host is one the runner answers `:pulled` for and never tries to fetch. The
registry credentials stay with whoever pulled it, which is where they belong.

The pull-on-404 retry in
`docs/a-missing-image-recovers-only-through-a-pull.md` is cheap to write. It
needs a pull it can call from `CyberDojoShRunner#create`, and that is this same
`POST /images/create`, which `NodeImages` already has.

## Reading the rag-lambda out of an image

The read does not have to run anything, so it is three plain `request` calls:

    POST   /containers/create              Image only, since it never runs
    GET    /containers/{id}/archive?path=/usr/local/bin/red_amber_green.rb
    DELETE /containers/{id}

None of `cyber_dojo_sh_runner.rb`'s machinery appears in it. No attach hijack, no
frame demultiplexing, no stdin to half-close, no deadline, no stop. The archive
response is a tar, and `TarFile::Reader#files` parses one and enforces the ustar
magic, so pulling the single entry out is a line. The create config is
`{'Image' => image_name}` and nothing else, since nothing executes.

The DELETE is not optional and belongs in an `ensure`. `AutoRemove` disposes of
a container that exits, and one that never starts never exits, so without the
DELETE every first-test-run-per-image leaves a container behind for good.
`traffic_light_test.rb:22ECB0` is what pins that it is issued; the real-daemon
test cannot, because the suite is parallel and creates real containers
elsewhere, so counting them would be flaky rather than stricter.

Nothing starts, and `docs/profiling/time_docker_run_split.sh` puts start at about 48ms
of daemon work against create at about 16ms. That saving lands on the first
test-run for an image after a restart, which is where TrafficLight's per-image
cache leaves it.

`DockerSocket#request` carries the tar without changes. `#attach` sets binmode
on its socket and `#request` does not, which looks like it would matter and does
not: `read_chunked_body` accumulates into `+''`, and `socket.read(size)` answers
ASCII-8BIT, so the empty buffer adopts ASCII-8BIT on the first append and stays
binary from there. Verified rather than assumed.

The other branch of `read_body` would not be safe. Plain `socket.read` with no
length answers the default external encoding, so it would tag tar bytes UTF-8.
Nothing reaches it: the daemon answers chunked whatever Connection it is asked
for, which is what the comment above `read_body` records.

The archive endpoint does answer for a container which was created and never
started, which `docs/profiling/check_archive_from_unstarted_container.rb` settles.
Against gcc_assert the container's state reads `created`, the archive answers
200 with a 2048 byte tar holding one entry, and its 170 bytes are byte for byte
what `docker run --rm --entrypoint=cat` answers for the same file. The whole
call takes about 5ms. The probe compares against the CLI rather than only
checking the status code, because answering 200 and answering the same thing
are different claims.

How busy that route is depends on the manifests. `runner.rb:31` only falls to
`colour_from_image` when the manifest carries no `rag_lambda`, and
`docs/start-points-without-a-manifest-rag-lambda.md` audits who that still is:
12 start-points of 83, eleven of them clang or java. Giving those twelve a
manifest `rag_lambda` empties the route of everything a start-point can reach.

It does not empty it of callers. A fork of an old kata, or an image someone
built themselves, still arrives without the field and cannot be upgraded from
here. Deleting `colour_from_image` therefore waits on somewhere else to answer
those, which is the ragger service in `docs/rag-functions-into-manifest.txt`.
Until that exists the route stays, and the twelve only decide how often it runs.

## What sinatra-base gives

`sinatra-base` is `ruby:4.0.5-alpine3.24` plus bash, tini, procps, util-linux
and tar, with its gems bundled in `/app`. That covers everything the runner
needs: `/sbin/tini` for the `ENTRYPOINT`, bash for `config/up.sh` and
`config/healthcheck.sh`, busybox `wget` for the healthcheck request, tar for
tar-piping coverage out of tmpfs. The runner's own `gem install concurrent-ruby`
line supplies the one gem the base does not carry.

The runner keeps `USER root`, because the socket it opens is root-owned and the
group that would replace root is a property of the host rather than of the
image. See `docs/docker-socket-privilege.md`, which also says why changing it
would buy less than it looks like it would.

`cyberdojo/docker-base` is not unused. Commander is still built from it.

## What is left

Worth doing but not blocking: giving the 12 start-points in
`docs/start-points-without-a-manifest-rag-lambda.md` a manifest `rag_lambda`,
which makes the create / archive / delete path rare rather than removing it.

`node.rb` and `node_images.rb` were the first two of these socket conversions,
and what the first cost is worth knowing before another. The endpoint was
the easy half. The daemon answers `RepoTags` for an image with no tags as `[]`
rather than as the CLI's `<none>:<none>`, so the filtering the CLI needed
disappeared; but `RepoTags` also carries digest-only references, eg
`alpine@sha256:...`, which `{{.Repository}}:{{.Tag}}` never printed. Those are
harmless, since `assert_versioned` refuses a digest-only name and no manifest
can hold one, but they falsified a rationale comment in `docker_image_name.rb`
that had been resting on what `docker image ls` answers. Expect each such swap
to move something a CLI format string was quietly hiding, and to find it only by
probing the real daemon: `test/server/node_test.rb:3q1Ps8` and
`test/server/node_images_test.rb:9j5t9S` are the shape of test that catches it,
and the stubs are what let it through.
