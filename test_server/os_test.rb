require_relative 'test_base'
require 'json'

class OsTest < TestBase

  def self.hex_prefix
    '669'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '8A2',
  %w( os-image correspondence ) do
    etc_issue = assert_cyber_dojo_sh('cat /etc/issue')
    diagnostic = [
      "image_name=:#{image_name}:",
      "did not find #{os} in etc/issue",
      etc_issue
    ].join("\n")
    assert etc_issue.include?(os.to_s), diagnostic
  end

end
