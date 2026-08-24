require_relative '../test_base'
require_code 'home_files'
require_code 'sandbox'

class HomeFilesGzipLevelTest < TestBase

  include HomeFiles

  test '4Ef2a9', %w[the container compresses its stdout at gzip level 1] do
    script = main_sh(Sandbox::DIR, Runner::MAX_FILE_SIZE)

    assert_includes script, 'gzip -1 < "${TAR_FILE}"', script
  end

  # Level 1 is the whole point of the flag: the compression is incidental on a
  # local pipe, the CRC32 and length trailer are what stop a corrupt payload
  # reaching the browser, and the default level costs three times as much to
  # get them. Losing the -1 would be invisible except as a slower traffic
  # light, which is why it is pinned here.
  # See docs/profiling/where-the-traffic-light-time-goes.txt
end
