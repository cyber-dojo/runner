require_relative 'test_base'

class OsTest < TestBase

  def self.hex_prefix
    '6691F'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '8A2',
  %w( os-image correspondence ) do
    in_kata_as(salmon) {
      etc_issue = assert_cyber_dojo_sh('cat /etc/issue')
      assert etc_issue.include?(os.to_s), etc_issue
    }
  end

end
