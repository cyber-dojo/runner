CVE Assessment: docker:29.4.1-dind-alpine3.23 for cyber-dojo
Generated: 2026-06-01 (curl/libcurl low-severity batch added 2026-07-03)

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
CVE-2026-39821         golang.org/x/net/idna    9.3   No   runner resolves only trusted endpoints; no user-controlled IDNA input
CVE-2026-33186         gRPC-Go                  9.1   No   --net=none; no gRPC exposure
CVE-2026-53488         containerd CRI labels    8.7   No   dockerd uses moby integration, not the CRI plugin; only trusted images run
CVE-2026-53488         containerd v2/client     8.7   No   same CVE as above, 2nd package (Snyk 17391516); CRI plugin path unused; only trusted images run
CVE-2026-29181         OTel baggage+family      8.7   No   --net=none; can't send baggage headers
CVE-2026-33814         golang.org/x/net/http2   8.7   No   --net=none; can't send SETTINGS frames
CVE-2026-46597         x/crypto/ssh             8.7   No   --net=none; no SSH server exposed
CVE-2026-39835         x/crypto/ssh             8.7   No   --net=none; no SSH server exposed
CVE-2026-46598         x/crypto/ssh/agent       8.7   No   --net=none; no SSH agent exposed
CVE-2026-48702         sigstore/rekor pkg/types 8.7   No   server-side DoS; runner runs no Rekor server; --net=none blocks user code
CVE-2026-39831         x/crypto/ssh             8.6   No   --net=none; client-side; no outbound SSH
CloudWatch-16316406    aws-sdk-go-v2 CloudWatch 8.2   No   --net=none; DoS only; requires MITM of TLS
CVE-2026-24051         OTel SDK resource        7.3   No   macOS-only (ioreg)
CVE-2026-39827         x/crypto/ssh             7.1   No   --net=none; no SSH server exposed
CVE-2026-41178         OTel baggage/propagation 6.9   No   Docker toolchain only; dockerd Unix socket; CLI tools, no inbound HTTP
CVE-2026-39829         x/crypto/ssh             6.9   No   --net=none; no SSH server exposed
CVE-2026-39834         x/crypto/ssh             6.9   No   --net=none; no SSH server exposed
CVE-2026-39830         x/crypto/ssh             6.9   No   --net=none; no SSH server exposed
CVE-2026-50195         containerd CRI checkpoint 5.6  No   CRI checkpoint import (Kubernetes); dockerd uses moby integration; not K8s; only trusted images (GHSA: Critical)
CVE-2026-50195         containerd v2/client     5.6   No   same CVE as above, 2nd package (Snyk 17393922); CRI checkpoint path unused; not K8s; only trusted images (GHSA: Critical)
CVE-2026-39828         x/crypto/ssh             5.3   No   --net=none; no SSH server exposed
CVE-2026-46595         x/crypto/ssh             5.3   No   --net=none; no SSH server exposed
CVE-2026-39832         x/crypto/ssh/agent       5.3   No   --net=none; no SSH agent exposed
CVE-2026-39833         x/crypto/ssh/agent       5.3   No   --net=none; no SSH agent exposed
CVE-2026-42506         golang.org/x/net/html    5.3   No   only docker-buildx links html pkg; build-time CLI; no untrusted HTML rendered
CVE-2026-27136         golang.org/x/net/html    5.3   No   only docker-buildx links html pkg; build-time CLI; no untrusted HTML rendered
CVE-2026-42502         golang.org/x/net/html    5.3   No   only docker-buildx links html pkg; build-time CLI; no untrusted HTML rendered
CVE-2026-25681         golang.org/x/net/html    5.3   No   only docker-buildx links html pkg; build-time CLI; no untrusted HTML rendered
CVE-2026-25680         golang.org/x/net/html    5.3   No   only docker-buildx links html pkg; build-time CLI; no untrusted HTML parsed
curl 18 CVEs (below)   Alpine curl < 8.21.0-r0  low   No   curl CLI removed; libcurl only via git (no net transport used); --net=none; see SNYK-ALPINE324-CURL.txt

== curl / libcurl low-severity batch (Alpine 3.24 apk "curl" < 8.21.0-r0) ==

The curl CLI is removed from the base image; the "curl" apk package remains only
because git links libcurl. All Low, NVD analysis pending (no CVSS yet).
Detail and exploitability assessment: docs/vulns/SNYK-ALPINE324-CURL.txt

CVE-2026-11586  SNYK-ALPINE324-CURL-17716543
CVE-2026-11352  SNYK-ALPINE324-CURL-17716663
CVE-2026-12064  SNYK-ALPINE324-CURL-17717190
CVE-2026-9079   SNYK-ALPINE324-CURL-17717313
CVE-2026-8286   SNYK-ALPINE324-CURL-17717410
CVE-2026-8932   SNYK-ALPINE324-CURL-17717433
CVE-2026-9545   SNYK-ALPINE324-CURL-17717489
CVE-2026-11564  SNYK-ALPINE324-CURL-17717495
CVE-2026-8458   SNYK-ALPINE324-CURL-17717584
CVE-2026-9546   SNYK-ALPINE324-CURL-17717618
CVE-2026-11856  SNYK-ALPINE324-CURL-17717651
CVE-2026-8925   SNYK-ALPINE324-CURL-17717674
CVE-2026-9547   SNYK-ALPINE324-CURL-17717707
CVE-2026-8924   SNYK-ALPINE324-CURL-17717716
CVE-2026-9080   SNYK-ALPINE324-CURL-17717717
CVE-2026-8926   SNYK-ALPINE324-CURL-17717718
CVE-2026-10536  SNYK-ALPINE324-CURL-17717719
CVE-2026-8927   SNYK-ALPINE324-CURL-17717720

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
