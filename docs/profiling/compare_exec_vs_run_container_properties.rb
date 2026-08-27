# frozen_string_literal: true

# Compares the container properties a test-run sees when it is exec'd into an
# already-started container against the properties it sees today, when a
# container is created around it. A test-run is one run of a kata's
# cyber-dojo.sh, which is what the browser's [test] button asks for.
#
# A pool of pre-started containers moves a test-run from create-and-run to
# exec, and an exec'd process is not the container's own process. Anything the daemon
# applies to that first process rather than to the container may not reach an
# exec. Ulimits are the doubt: cyber_dojo_sh_host_config.rb sends them in
# HostConfig, and test/client/container_properties_test.rb 3A8D99 pins what a
# kata sees. HOME and the CYBER_DOJO_* vars are the same class of question, and
# 3A8D98 pins those. This probe answers all of them at once.
#
# It also answers whether the daemon honours Env on exec, since the exec side
# passes the CYBER_DOJO_* vars that way and an ignored Env shows up as empty
# values in the diff.
#
# Both sides run the same command, under the same production config, with the
# same id, so every line that differs is a real divergence and nothing else.
#
# What it does not cover is the payload path, stdin in and frames out, which
# time_test_run_via_daemon_api_vs_cli.rb already exercises over an exec. The run
# side still opens stdin and closes it, because that is the shape production
# uses and a run given no stdin at all behaves differently.
#
# Run on the host:
#
#   ruby docs/profiling/compare_exec_vs_run_container_properties.rb
#
# Exits non-zero when the two disagree, so a clean exit is the answer step 0 of
# docs/pre-started-container-pool.md is waiting for.

require 'json'
require 'socket'
require_relative '../../source/server/cyber_dojo_sh_container_config'
require_relative '../../source/server/docker_attach_frames'
require_relative '../../source/server/externals/unix_socket_http'
require_relative '../../source/server/sandbox'

IMAGE = ARGV[0] || 'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'
SOCKET_PATH = '/var/run/docker.sock'
ID = '9U3Kry'

# What both sides print. Every line is a property some test pins, or a property
# a kata would notice losing. ulimit -a arrives whole rather than limit by
# limit, so that no limit is missed by being forgotten here.
#
# The parts are joined into one line, the way container_properties_test.rb
# joins its own. Init runs tini as PID 1 and tini's argv carries the command it
# wraps, so a newline in the command becomes a line of /proc/1/cmdline, which
# the probe reads back a few parts later.
PROBE_PARTS = [
  'echo "home=${HOME}"',
  'echo "image_name=${CYBER_DOJO_IMAGE_NAME}"',
  'echo "id=${CYBER_DOJO_ID}"',
  'echo "sandbox=${CYBER_DOJO_SANDBOX}"',
  'echo "uid=$(id -u)"',
  'echo "gid=$(id -g)"',
  'echo "groups=$(id -G)"',
  'echo "proc1=$(cut -c1-9 /proc/1/cmdline)"',
  'echo "passwd=$(getent passwd $(id -u))"',
  "echo \"sandbox_stat=$(stat --printf='%u:%g:%A' #{Sandbox::DIR})\"",
  "echo \"tmp_stat=$(stat --printf='%u:%g:%A' /tmp)\"",
  "echo \"sandbox_write=$(touch #{Sandbox::DIR}/probe 2>/dev/null && echo yes || echo no)\"",
  "ulimit -a | sed 's/^/ulimit /'"
].freeze

PROBE_BODY = PROBE_PARTS.join('; ')

# The daemon, spoken to the way the runner speaks to it.
def client
  @client ||= UnixSocketHttp.new(SOCKET_PATH)
end

# Answers the new container's id. A refusal is raised rather than carried on
# with, since every later call needs that id.
def create(name, body)
  code, response = client.request('POST', "/containers/create?name=#{name}", body)
  raise "create answered #{code}: #{response}" unless code.between?(200, 299)

  JSON.parse(response)['Id']
end

# Runs the container's own command.
def start(container_id)
  code, response = client.request('POST', "/containers/#{container_id}/start")
  raise "start answered #{code}: #{response}" unless code.between?(200, 299)
end

# The production config, with the probe in place of the kata's own command and
# nothing else touched. The stdio group is left alone in particular: a run that
# is given no stdin at all is not the run production does, and what it hands a
# command that reads one is not the same either.
def probe_config(cmd)
  CyberDojoShContainerConfig.create_config(ID, IMAGE).merge('Cmd' => ['bash', '-c', cmd])
end

# The properties as a test-run sees them today: a container created around the
# command, attached to before it starts so that no output is missed.
def properties_via_run
  container_id = create("probe_run_#{Process.pid}", probe_config(PROBE_BODY))
  stream = client.attach("/containers/#{container_id}/attach?stream=1&stdin=1&stdout=1&stderr=1")
  start(container_id)
  # The payload a test-run would send is empty here, but the half-close still has
  # to happen: it is what gives stdin an end, and a command reading one waits
  # for ever without it.
  stream.close_write
  stdout, = DockerAttachFrames.demultiplex(stream)
  stream.close
  stdout
end

# The properties as a test-run would see them from a pool: a container already
# sleeping, exec'd into. The vars a test-run carries are passed on the exec, which
# is where they would have to live once create no longer knows them.
def properties_via_exec
  container_id = create("probe_exec_#{Process.pid}", probe_config('sleep 60'))
  start(container_id)
  stdout = exec_probe(container_id)
  stop(container_id)
  stdout
end

# Answers what the probe printed inside the already-running container.
def exec_probe(container_id)
  exec_id = exec_create(container_id)
  stream = exec_start(exec_id)
  stdout, = DockerAttachFrames.demultiplex(stream)
  stream.close
  stdout
end

# Answers the new exec's id. The user and the vars are set here because a
# pooled container was created before either was known.
def exec_create(container_id)
  code, response = client.request('POST', "/containers/#{container_id}/exec", {
                                    'AttachStdin' => false,
                                    'AttachStdout' => true,
                                    'AttachStderr' => true,
                                    'Tty' => false,
                                    'User' => "#{Sandbox::UID}:#{Sandbox::GID}",
                                    'Env' => [
                                      "CYBER_DOJO_IMAGE_NAME=#{IMAGE}",
                                      "CYBER_DOJO_ID=#{ID}",
                                      "CYBER_DOJO_SANDBOX=#{Sandbox::DIR}"
                                    ],
                                    'Cmd' => ['bash', '-c', PROBE_BODY]
                                  })
  raise "exec create answered #{code}: #{response}" unless code.between?(200, 299)

  JSON.parse(response)['Id']
end

# Starting an exec hijacks the connection the way attach does, but it carries a
# body where attach carries none, so the request is written here rather than
# through UnixSocketHttp#attach.
def exec_start(exec_id)
  socket = UNIXSocket.new(SOCKET_PATH)
  body = JSON.generate({ 'Detach' => false, 'Tty' => false })
  socket.write(
    "POST /exec/#{exec_id}/start HTTP/1.1\r\nHost: docker\r\n" \
    "Content-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n" \
    "Upgrade: tcp\r\nConnection: Upgrade\r\n\r\n#{body}"
  )
  socket.gets
  while (line = socket.gets)
    break if ["\r\n", "\n"].include?(line)
  end
  socket.binmode
  socket
end

# A sleeping container outlives the probe unless it is stopped, and AutoRemove
# disposes of it once it is.
def stop(container_id)
  client.request('POST', "/containers/#{container_id}/stop?t=1")
end

# Every property, side by side, with the ones that disagree named. A difference
# is not a failure of the probe: it is the answer, and it says what a pool has
# to carry onto the exec itself.
def report(run, exec)
  run_properties = keyed(run)
  exec_properties = keyed(exec)
  names = run_properties.keys | exec_properties.keys
  differences = names.reject { |name| run_properties[name] == exec_properties[name] }

  puts(format('%-38s %-20s %-20s', 'property', 'run', 'exec'))
  names.each do |name|
    differs = differences.include?(name) ? ' <-- differs' : ''
    puts(format('%-38s %-20s %-20s%s', name, run_properties[name], exec_properties[name], differs))
  end
  differences
end

# Each printed line as name and value, so that the two sides line up by name
# rather than by position. An echo'd line separates the two with its =, and a
# ulimit -a line ends with its value, having spent everything before it naming
# the limit.
def keyed(stdout)
  stdout.split("\n").each_with_object({}) do |line, memo|
    if line.start_with?('ulimit ')
      name, _sep, value = line.rpartition(/\s+/)
      memo[name.strip] = value.strip
    else
      name, _sep, value = line.partition('=')
      memo[name.strip] = value.strip
    end
  end
end

run_stdout = properties_via_run
exec_stdout = properties_via_exec
differences = report(run_stdout, exec_stdout)
puts
if differences.empty?
  puts('Same properties either way. An exec\'d test-run is indistinguishable.')
else
  puts("Differ: #{differences.join(', ')}")
  # What each side actually sent, so that a difference can be read rather than
  # inferred from a name the parsing chose.
  puts("\n--- run stdout ---\n#{run_stdout}")
  puts("\n--- exec stdout ---\n#{exec_stdout}")
end
exit(differences.empty? ? 0 : 1)
