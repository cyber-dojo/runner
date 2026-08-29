# The docker socket, and why the runner runs as root

The runner's `Dockerfile` ends with `USER root`. Saver and the other services
drop to an unprivileged user, so the runner looks like the odd one out. It is,
and this is what it would take to change, and why the obvious change is worth
less than it appears.

## Why root today

`docker-compose.yml` bind-mounts the host's socket into the container:

    - /var/run/docker.sock:/var/run/docker.sock

A bind-mounted socket keeps the ownership it has on the host, expressed as raw
numeric ids. On a developer machine running Docker Desktop that is:

    srw-rw---- 1 0 0 /var/run/docker.sock

root:root, mode 660. No group holds any permission on it, so no group is
joinable, and only uid 0 can open it.

Three places currently agree that the runner is root, and all three have to
agree or the container cannot reach the daemon:

- `Dockerfile`, `USER root`
- `bin/echo_env_vars.sh`, `CYBER_DOJO_RUNNER_SERVER_USER=root`, which
  `docker-compose.yml` passes as the service's `user:`
- `deployment/terraform/deployment.tf`, which sets no `user` at all, so ECS
  runs the image's own

## Why a docker group does not solve it

On a Linux host the socket is `root:docker` rather than root:root, so the
question becomes whether the runner can run as a user in that group. See
https://estl.tech/accessing-docker-from-a-kubernetes-pod-68996709c04b

The group's GID is a property of the host, not of the image. It differs between
distributions and between AMIs. Putting it in the `Dockerfile` makes the image
correct for one host and wrong for the next, which is the opposite of what a
built artifact should be. The mechanism that gets it right supplies the GID at
deploy time instead, as ECS `user: "uid:gid"` or compose `group_add:`, which
puts a host fact in the task definition where it belongs.

That still leaves the developer machine, where the socket has no group to join,
so the local and deployed configurations would have to differ on exactly the
thing they should agree about. A runner that is root locally and non-root in
production is a runner whose permission behaviour is only ever tested in one of
the two places it runs.

## Why it would buy little anyway

Reaching the docker daemon is equivalent to being root on the host. Anything
that can create a container can create a privileged one with the host's
filesystem mounted, whatever uid asked for it. So dropping the runner to a
non-root uid, while leaving the socket mounted, moves nothing that an attacker
who reached the runner would care about. The privilege is the socket, not the
uid.

## What would reduce it

Refusing what the runner does not use. Every call it makes on the daemon is a
method on `DockerDaemon`, so the whole set is that one class rather than
something to be gathered from its callers:

| Endpoint | `DockerDaemon` | Caller |
| --- | --- | --- |
| `GET /images/json` | `image_names` | `node_images.rb` |
| `POST /images/create?fromImage=` | `pull_image` | `node_images.rb` |
| `POST /containers/create` | `create_container` | `cyber_dojo_sh_runner.rb`, `traffic_light.rb` |
| `POST /containers/{id}/start` | `start_container` | `cyber_dojo_sh_runner.rb` |
| `POST /containers/{id}/exec` | `create_exec` | `cyber_dojo_sh_runner.rb` |
| `POST /exec/{id}/start` | `start_exec` | `cyber_dojo_sh_runner.rb` |
| `POST /containers/{id}/stop` | `stop_container` | `cyber_dojo_sh_runner.rb` |
| `GET /containers/{id}/archive` | `read_file` | `traffic_light.rb` |
| `DELETE /containers/{id}` | `remove_container` | `traffic_light.rb` |

A proxy in front of the socket that allows those and refuses everything else
removes the privileged-container escape, and it does so without the runner
having to stop being root. Note what it does not remove: `POST
/containers/create` is on the list because the runner's whole job is creating
containers, so a proxy has to judge the config it is asked for rather than only
the path. `CyberDojoShContainerConfig` is where the runner's own answer to that
question already lives.

There are two bodies to judge rather than one. `image_config` says what the
container may do, and `exec_config` carries the command that runs the kata, so
a proxy that read only the create config would see the limits and never the
command, and would allow any command at all on the exec. Both endpoints have to
be judged on their body and not merely their path.

Enumerating this list was not practical while the runner spawned the docker
CLI, because the CLI's flags do not map one-to-one onto endpoints and the CLI
is free to call others. It became possible when the last CLI caller went.

## Not settled here

Which proxy, and whether the create-config check can be expressed in it. Also
whether ECS on the deployed AMI presents the socket as root:docker at all: this
document only measures Docker Desktop, and the deployed host has not been
checked.
