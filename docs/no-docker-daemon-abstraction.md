# context.daemon is a transport, not a daemon

`context.daemon` answers a `UnixSocketHttp`, so every caller writes its own
docker URL:

    daemon.request('GET', '/images/json')
    daemon.request('POST', "/images/create?fromImage=#{image_name}")
    daemon.request('GET', "/containers/#{id}/archive?path=#{RAG_LAMBDA_FILENAME}")

The class is right about itself. Its comment says it speaks HTTP over a unix
socket of any kind, and `context.rb` puts the socket path at the wiring for
that reason. A transport taking a path per call is what `Net::HTTP` does too:
the path it owns is the socket's, not the URL's.

The name is what does not fit. `daemon` promises something that knows about
docker and delivers something that knows about HTTP, which is why the URLs look
like they are on the wrong side of the boundary. They are on the only side
there is.

## What is spread out

Four files assemble docker URLs: `node.rb`, `puller.rb`, `traffic_light.rb`,
`daemon_run.rb`. `DaemonRun` is already the abstraction this describes, for the
run sequence alone; the other three have no equivalent and reach the transport
directly.

Two things this costs, both observed rather than imagined:

- `docs/docker-socket-privilege.md` needs the complete list of endpoints the
  runner uses, to say what a socket proxy would allow. That list had to be
  reconstructed by grepping four files. An abstraction would be the list.
- Three test doubles stand in for the daemon: `DaemonOneRequestStub`,
  `DaemonSequenceStub`, `DaemonStub`. All three match on the URL, and the last
  routes on `path.start_with?('/containers/create')` after an earlier version
  routed on the substring `create` and would have answered an image pull as a
  container create. Stubs match on URLs because the seam is at the transport.

## The shape it would take

A `DockerDaemon` holding a `UnixSocketHttp`, answering `image_names`,
`pull_image(name)`, `create_container(config)`, `read_file(id, path)` and
`remove_container(id)`. `context.daemon` would answer that, and the transport
would become something only it holds.

Against it: the whole daemon surface is eight endpoints in a service of this
size, so the layer earns its keep only if something else wants that list, and
`DaemonRun` would have to move inside it or go on holding its own client.
Deciding that is not urgent, and nothing is broken while it stays as it is.
