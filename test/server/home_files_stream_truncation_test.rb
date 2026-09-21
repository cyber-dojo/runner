require_relative '../test_base'
require_code 'home_files'
require_code 'sandbox'

class HomeFilesStreamTruncationTest < TestBase

  include HomeFiles

  test '7Bq4vH', %w[
  | the container truncates cyber-dojo.sh's stdout and stderr
  | alongside the files under the sandbox dir
  ] do
    script = main_sh(Sandbox::DIR, Runner::MAX_FILE_SIZE)

    operands = truncate_find_line(script)

    assert_includes operands, Sandbox::DIR, script
    assert_includes operands, '/tmp/stdout', script
    assert_includes operands, '/tmp/stderr', script
  end

  # The two streams reach the browser truncated either way, because runner.rb
  # cuts every payload member to MAX_FILE_SIZE. What this pins is where: cut in
  # the container, 50K crosses the daemon socket; cut in the runner, everything
  # cyber-dojo.sh printed does, to be tarred, gzipped, inflated, untarred and
  # transcoded before all but the first 50K is dropped. /tmp is a 250MB tmpfs
  # holding the tar as well, so a chatty kata can fill it.
  # See test/client/file_truncation_test.rb for what the browser is left with.

  private

  # The find whose matches are truncated, named by the size it selects on so
  # that the binary-file scan's own find (-size +1c) cannot be mistaken for it.
  def truncate_find_line(script)
    selector = "-size +#{Runner::MAX_FILE_SIZE}c"
    line = script.lines.find { |each| each.include?(selector) }
    refute_nil line, script
    line
  end
end
