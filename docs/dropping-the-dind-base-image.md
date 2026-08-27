# Dropping the dind base image

The runner's image is built `FROM cyberdojo/docker-base`, which is
`docker:29.7.2-dind-alpine3.24` plus ruby and a handful of gems. The only thing
that base supplies which the runner actually uses at runtime is the `docker`
CLI binary. If the last three CLI callers move to the daemon's HTTP API, the
runner can be built `FROM ghcr.io/cyber-dojo/sinatra-base` instead, the same as
saver and the other services.

## Why the daemon socket is not the obstacle

The runner does not run a docker daemon of its own. It talks to the host's
daemon through the socket bind-mounted by `docker-compose.yml`:

    - /var/run/docker.sock:/var/run/docker.sock

That mount is a compose / task-definition concern. It works regardless of which
base image the runner is built from, because opening a unix socket needs no
docker binaries at all: `source/server/externals/unix_socket_http.rb` speaks
HTTP over the socket directly.

So "runner needs the docker socket" and "runner needs a dind base image" are
separate claims, and only the first is true.

## The three remaining CLI callers

Each goes through `context.sheller` (`BashSheller`, which is `Open3.capture3`):

| Site | Command | Daemon endpoint |
| --- | --- | --- |
| `source/server/node.rb:7` | `docker image ls --format '{{.Repository}}:{{.Tag}}'` | `GET /images/json` |
| `source/server/puller.rb:37` | `docker pull <image>` | `POST /images/create?fromImage=&tag=` |
| `source/server/traffic_light.rb:76` | `docker run --rm --entrypoint=cat <image> <rag-lambda-file>` | create + start + attach + remove |

The first two are thin. `GET /images/json` answers each image's `RepoTags`, so
`image_names` becomes a flatten-and-sort over that array rather than splitting
lines of CLI output; the `<none>:<none>` entry the CLI prints is simply absent
from the API's `RepoTags`. `POST /images/create` streams newline-delimited JSON
progress objects and returns 200 before the pull finishes, so the caller must
drain the stream to the end and treat a trailing object containing an `error`
key as failure. The CLI's non-zero exit status has no direct equivalent.

Do that one alongside the pull-on-404 retry in
`docs/a-missing-image-recovers-only-through-puller.md`. The retry needs a pull
it can call from `DaemonRun#create`, which is this same `POST /images/create`
and this same stream-draining, so writing them apart writes them twice.

The third looks like the real work and is not, because it does not have to run
anything. `docker run --entrypoint=cat` starts a container only to read one
file back out of it, and the daemon will copy a file out of a container that
has never been started. So the sequence is three plain `client.request` calls:

    POST   /containers/create              Image only, since it never runs
    GET    /containers/{id}/archive?path=/usr/local/bin/red_amber_green.rb
    DELETE /containers/{id}

None of `daemon_run.rb`'s machinery is needed for it. No attach hijack, no
frame demultiplexing, no stdin to half-close, no deadline, no stop. The archive
response is a tar, and `TarFile::Reader#files` already parses one and enforces
the ustar magic, so pulling the single entry out is a line. What replaces
`checked_read_lambda_source` is on the order of 25 lines, plus a create config
far smaller than `CyberDojoShContainerConfig` because nothing executes.

It should also be quicker than what it replaces. Nothing starts, and
profiling/time_docker_run_split.sh puts start at about 48ms of daemon work
against create at about 16ms. The saving lands on the first test-run for an
image after a restart, which is where TrafficLight's per-image cache leaves it.

`UnixSocketHttp#request` carries the tar without changes.
`#attach` sets binmode on its socket and `#request` does not, which looks like
it would matter and does not: `read_chunked_body` accumulates into `+''`, and
`socket.read(size)` answers ASCII-8BIT, so the empty buffer adopts ASCII-8BIT
on the first append and stays binary from there. Verified rather than assumed.

The other branch of `read_body` would not be safe. Plain `socket.read` with no
length answers the default external encoding, so it would tag tar bytes UTF-8.
Nothing reaches it: the daemon answers chunked whatever Connection it is asked
for, which is what the comment above `read_body` records.

Not verified here: that the archive endpoint answers for a container which was
created and never started. It is how `docker cp` behaves against a stopped
container, but that is the API's documented behaviour rather than something
measured in this repo. A probe alongside the others in profiling/ would settle
it, and is the first thing to write.

How much has to be written depends on how busy that route still is.
`runner.rb:31` only falls to `colour_from_image` when the manifest carries no
`rag_lambda`, and `docs/start-points-without-a-manifest-rag-lambda.md` audits
who that still is: 12 start-points of 83, eleven of them clang or java. Giving
those twelve a manifest `rag_lambda` empties the route of everything a
start-point can reach.

It does not empty it of callers. A fork of an old kata, or an image someone
built themselves, still arrives without the field and cannot be upgraded from
here. Deleting `colour_from_image` therefore waits on somewhere else to answer
those, which is the ragger service in `docs/rag-functions-into-manifest.txt`.
Until that exists this converts by rewrite, and the twelve only decide how
often the rewritten path runs.

## What sinatra-base gives, and what the switch costs

`sinatra-base` is `ruby:4.0.5-alpine3.24` plus bash, tini, procps, util-linux
and tar, with its gems bundled in `/app`. That covers everything the runner
needs once the CLI has no callers: `/sbin/tini` for the `ENTRYPOINT`, bash for
`config/up.sh` and `config/healthcheck.sh`, busybox `wget` for the healthcheck
request, tar for tar-piping coverage out of tmpfs.

Points to settle before committing to the change:

- The runner must keep `USER root`, or run as a user in the group owning
  `/var/run/docker.sock`. Saver drops to an unprivileged `saver` user; the
  runner cannot do the same without matching that group. See
  `docs/runner-as-docker-group.txt`.
- Ruby changes from Alpine's `ruby-dev` package to the official
  `ruby:4.0.5-alpine3.24` image, and the inherited gem set changes from
  `docker-base`'s Gemfile to `sinatra-base`'s. Both carry json, puma, rack,
  thin, prometheus-client, minitest and simplecov. `docker-base` additionally
  carries coveralls and ruby-prof; `sinatra-base` additionally carries sinatra,
  nokogiri, capybara and selenium-webdriver. The runner's own
  `gem install concurrent-ruby` line stays either way.
- Two `RUN` lines in `Dockerfile` exist only to undo dind and are deleted with
  it: `apk del git` (git arrives from `docker:dind` and drags in libcurl) and
  the `rm -rf` of the buildx CLI plugin. Both of their long explanatory
  comments go too.
- `docker-base` does not become unused. Commander is still built from it.

## Order of work

1. `node.rb` to `GET /images/json`. Smallest, and `test/server/node_test.rb`
   pins the behaviour already.
2. `puller.rb` to `POST /images/create`. Needs a decision on what counts as a
   failed pull now that there is no exit status.
3. `traffic_light.rb` to create / archive / delete, after a probe confirms the
   archive endpoint answers for a container that was never started. Giving the
   12 start-points a manifest `rag_lambda` is worth doing alongside, because it
   makes this path rare, but it does not remove the need to write it.
4. Delete `BashSheller`, `BashShellerStub`, `context.sheller` and their tests.
5. Rebase the `Dockerfile` on `sinatra-base` and drop the two dind-undoing
   `RUN` lines.

Steps 1 to 4 are useful on their own: they remove the last `Open3` subprocess
spawn from a request path. Step 5 is what turns that into a smaller image and a
smaller Snyk surface.
