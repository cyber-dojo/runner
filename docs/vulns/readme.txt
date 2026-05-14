CVE Assessment: docker:29.4.1-dind-alpine3.23 for cyber-dojo
Generated: 2026-04-30

Each vulnerability has its own file in this directory named after its CVE or Snyk ID.

== Runner security posture ==

User code runs as UID 41966:51966 (non-root, non-privileged)
--net=none on every sandbox container -- no network access whatsoever
--security-opt=no-new-privileges -- blocks setuid escalation
No --privileged flag
--pids-limit=128, memory capped, ulimits set
Runner reaches Docker via mounted socket (/var/run/docker.sock), not from inside the sandbox

== Summary table ==

CVE / ID               Package                 Score  Exploitable?  Reason
------------------------------------------------------------------------------
CVE-2026-33186         gRPC-Go                  9.1   No   --net=none; no gRPC exposure
CVE-2026-34040         Docker Engine            8.8   No   No AuthZ plugins in use
CVE-2026-29181         OTel baggage+family      8.7   No   --net=none; can't send baggage headers
CVE-2026-35469         spdystream               8.7   No   --net=none; DoS only
CVE-2026-33814         golang.org/x/net/http2   8.7   No   --net=none; can't send SETTINGS frames
CVE-2026-33747         buildkit/source/http     8.6   No   docker build not used with user content
CVE-2026-33748         buildkit git/llb/gitutil 8.2   No   docker build not used with user content
CloudWatch-16316406    aws-sdk-go-v2 CloudWatch 8.2   No   --net=none; DoS only; requires MITM of TLS
CVE-2026-35385         OpenSSH server           7.5   No   --net=none; sshd not running
CVE-2026-3805          curl                     7.5   No   --net=none
CVE-2026-27135         nghttp2                  7.5   No   --net=none
CVE-2026-32280         Go stdlib                7.5   No   No Docker socket access from sandbox
CVE-2026-32281         Go stdlib                7.5   No   No Docker socket access from sandbox
CVE-2026-32283         Go stdlib                7.5   No   No Docker socket access from sandbox
CVE-2026-34986         go-jose v4               7.5   No   --net=none; no JWE endpoint exposed
CVE-2025-52881         opencontainers/selinux   7.3   No   /proc namespaced; no-new-privileges
CVE-2026-24051         OTel SDK resource        7.3   No   macOS-only (ioreg)
CVE-2025-47913         x/crypto/ssh/agent       7.1   No   --net=none; no SSH agent exposed
CVE-2025-15558         docker/cli plugins       7.0   No   Linux deployment; Windows-only
CVE-2025-58181         x/crypto/ssh             6.9   No   --net=none; no SSH server exposed
CVE-2025-47914         x/crypto/ssh/agent       6.9   No   --net=none; no SSH agent exposed
CVE-2025-58190         x/net/html               6.9   No   --net=none; can't reach HTML parser
CVE-2025-47911         x/net/html               6.9   No   --net=none; can't reach HTML parser
sigstore-ts-auth(Snyk) sigstore/ts-authority    6.7   No   cosign in service image; not accessible from sandbox
CVE-2025-61985         OpenSSH client           5.3   No   --net=none; ProxyCommand not configured
CVE-2025-61984         OpenSSH client           5.3   No   --net=none; ProxyCommand not configured
bbolt (no CVE yet)     go.etcd.io/bbolt         n/a   No   Requires corrupted containerd metadata

== Key caveat ==

None of these are container escape vulnerabilities (runc escapes, kernel exploits).
Those are what would matter most for cyber-dojo's threat model. The CVEs listed are
mostly: network-service auth bugs (irrelevant with --net=none), Docker auth-plugin
bypass (irrelevant without plugins), BuildKit build-time flaws (irrelevant as
cyber-dojo doesn't build images from user content), and DoS issues. The runner's
defence-in-depth -- non-root user, no network, no-new-privileges, pid limits, tmpfs
isolation -- specifically neutralises the attack vectors these CVEs require.

The higher-value scan to run would target runc and containerd CVEs specifically,
since those are the components that actually mediate the boundary between user code
and the host.
