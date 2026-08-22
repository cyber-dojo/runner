CVE Assessment: cyberdojo/runner (FROM cyberdojo/docker-base:909ba1d, docker 29.7.2-dind-alpine3.24) for cyber-dojo
Generated: 2026-08-22

Each vulnerability has its own file in this directory named after its CVE or Snyk
ID. There is one file per vulnerability the current scan reports, and no others.
When a scan stops reporting a vulnerability, its file and its .snyk entry are
removed; git holds the earlier assessments.

== Runner security posture ==

User code runs as UID 41966:51966 (non-root, non-privileged)
--net=none on every sandbox container, so no network access whatsoever
--security-opt=no-new-privileges blocks setuid escalation
No --privileged flag
--pids-limit=128, memory capped, ulimits set
Runner reaches Docker via mounted socket (/var/run/docker.sock), not from inside the sandbox

== Binaries absent from the image ==

The Dockerfile deletes two things the runner never uses at runtime, so their
vulnerabilities leave the scan rather than needing an assessment:

git           "apk del git". git is the sole package pulling in libcurl, so the
              Alpine libcurl CVEs go with it. Only host-side build scripts run
              git. commander keeps git via docker-base, as it uses "git clone"
              at runtime.
docker-buildx the CLI plugin is deleted. Runner drives docker only through run,
              stop, rm, pull and image. buildx is the one binary still vendoring
              a vulnerable moby/go-archive, and the source of every buildkit
              finding.

== Summary table ==

CVE / ID               Package                 Score  Exploitable?  Reason
------------------------------------------------------------------------------
grpc-18172578          grpc internal/transport  8.8   No   vulnerable v1.80.0 only in containerd/ctr; local Unix sockets; no xDS RBAC configured; --net=none
CloudWatch-16316406    aws-sdk-go-v2 CloudWatch 8.2   No   --net=none; DoS only; requires MITM of TLS
CVE-2026-41178         OTel baggage/propagation 6.9   No   only containerd/ctr still on otel v1.43.0; containerd API is a local Unix socket; ctr is a CLI
CVE-2026-10722         cilium/ebpf/btf          4.8   No   sandboxed user code lacks CAP_BPF to load eBPF; only trusted toolchain BTF specs parsed; DoS only

== Deleted rather than assessed ==

CVE-2026-17106 (moby/go-archive, Snyk 18958666, 7.1 High) is reported against the
image built before buildx was deleted. The only vulnerable copy is docker-buildx
v0.2.1; dockerd vendors v0.3.3 and docker-compose v0.3.2, both patched, so the
layer extraction that "docker pull" performs is unaffected. It has no .snyk entry
because the Dockerfile removes the binary instead. The plugin comes from the base
image, so the deletion marks it removed in a later layer rather than dropping the
layer: the image is no smaller to pull, but the binary is absent from the running
container and from the filesystem the scanner sees. The next scan shows whether
that clears the finding.

== Key caveat ==

None of the assessed vulnerabilities is a container escape (runc escapes, kernel
exploits). Those are what would matter most for cyber-dojo's threat model. What
remains is denial of service reachable only from a position user code does not
hold (CloudWatch needs MITM of a TLS connection, the BTF overflow needs the
ability to load eBPF), and control-plane surfaces exposed only on local Unix
sockets (grpc and OTel baggage in containerd). The runner's defence-in-depth
(non-root user, no network, no-new-privileges, pid limits, tmpfs isolation)
specifically neutralises the attack vectors these require.

The higher-value scan to run would target runc and containerd CVEs specifically,
since those are the components that actually mediate the boundary between user code
and the host.
