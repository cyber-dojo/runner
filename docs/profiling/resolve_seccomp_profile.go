// Resolves dockerd's default seccomp profile for one capability set, using
// dockerd's own loader, and prints the OCI linux.seccomp it produces.
//
// ../../source/server/seccomp/ holds what this printed. Those two files are
// what CyberDojoShOciConfig gives an OCI runtime, so that a kata run by crun is
// refused the syscalls dockerd refuses it today. They are generated rather than
// written, and this is the generator.
//
// Why a generator is needed at all. dockerd's profile is not an OCI profile: it
// carries archMap, and includes/excludes keyed on arch, minKernel and caps,
// which an OCI runtime knows nothing about. GetDefaultProfile evaluates those
// against the spec it is given and the machine it runs on, and answers a flat
// profile. Doing that evaluation by hand is how a syscall gets allowed that
// dockerd refuses, silently.
//
// So the arch and the kernel of whatever runs this are part of the answer, and
// so is the capability set passed as arguments.
//
// What produced the files in source/server/seccomp:
//
//   docker run --rm --platform linux/amd64 \
//     --volume <repo>/docs/profiling:/src golang:1.25-alpine \
//     sh -c 'cd /src && go mod init resolve && go mod tidy && go run . <caps>'
//
// amd64.json came from the fourteen capabilities dockerd leaves a container,
// and amd64_with_ptrace.json from those plus CAP_SYS_PTRACE, which is what a
// clang image is given. docs/profiling/check_test_run_confinement.rb is what
// measured both sets.
//
// The inputs that produced the committed files, none of which the files
// themselves record:
//
//   upstream   github.com/moby/profiles, seccomp/default.json,
//              commit 3c28324314729dbade8287e868eef6338c42807a, 2026-05-06
//   platform   linux/amd64, giving SCMP_ARCH_X86_64 with X86 and X32
//   kernel     7.0.12-linuxkit, which is what minKernel was compared against
//
// Regenerate when any of those moves, or when the capability set does. Nothing
// enforces that, which is the weakest part of this arrangement: a profile that
// has drifted from the daemon's still runs, and still passes every test, while
// allowing a kata something dockerd would not.
//
// The platform matters more than it looks. The runner image is amd64, but a
// language image is multi-arch, and a kata runs in the language image. On an
// arm64 developer machine those containers are arm64, so these two files
// describe production and not that machine.
package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/moby/profiles/seccomp"
	specs "github.com/opencontainers/runtime-spec/specs-go"
)

func main() {
	spec := &specs.Spec{
		Process: &specs.Process{
			Capabilities: &specs.LinuxCapabilities{
				Bounding: os.Args[1:],
			},
		},
	}

	profile, err := seccomp.GetDefaultProfile(spec)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}

	out, err := json.MarshalIndent(profile, "", "  ")
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
	fmt.Println(string(out))
}
