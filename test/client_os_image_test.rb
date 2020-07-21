# frozen_string_literal: true
require_relative 'test_base'

class ClientOsImageTest < TestBase

  def self.id58_prefix
    '237'
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '8A1',
  'start-files image_name<->os correspondence' do
    etc_issue = assert_cyber_dojo_sh('cat /etc/issue')
    diagnostic = [
      "image_name=:#{image_name}:",
      "did not find #{os} in etc/issue",
      etc_issue
    ].join("\n")
    case os
    when :Alpine
      assert etc_issue.include?('Alpine'), diagnostic
    when :Ubuntu
      assert etc_issue.include?('Ubuntu'), diagnostic
    end
  end

end
