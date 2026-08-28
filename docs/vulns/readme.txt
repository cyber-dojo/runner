CVE Assessment: cyberdojo/runner (FROM ghcr.io/cyber-dojo/sinatra-base, ruby:4.0.5-alpine3.24) for cyber-dojo
Generated: 2026-08-28

Each vulnerability has its own file in this directory named after its CVE or Snyk
ID. There is one file per vulnerability the current scan reports, and no others.
When a scan stops reporting a vulnerability, its file and its .snyk entry are
removed; git holds the earlier assessments.

== Runner security posture ==

User code runs as UID 41966:51966 (non-root, non-privileged)
NetworkMode 'none' on every sandbox container, so no network access whatsoever
SecurityOpt 'no-new-privileges' blocks setuid escalation
No Privileged flag
PidsLimit 128, Memory capped at 2GB, ulimits set
Runner reaches the daemon via the mounted socket (/var/run/docker.sock), not from
inside the sandbox

These are set in source/server/cyber_dojo_sh_host_config.rb, on the HostConfig of
the POST /containers/create that starts a run.

== Summary table ==

The current scan reports no vulnerabilities, so there is nothing to assess and
.snyk carries no ignore entries.

CVE / ID               Package                 Score  Exploitable?  Reason
------------------------------------------------------------------------------
(none)

== Key caveat ==

What would matter most for cyber-dojo's threat model is a container escape: a
runc escape or a kernel exploit. Neither runc nor containerd is part of this
image, so scanning the image never covers them. They run on the host, mediating
the boundary between user code and that host, and a scan targeting them is the
higher-value one to run.

What the image scan does cover is the runner's own ruby stack. The runner's
defence in depth against anything found there is above: non-root user, no
network, no-new-privileges, pid limits, tmpfs isolation.
