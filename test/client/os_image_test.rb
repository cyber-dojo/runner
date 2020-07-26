# frozen_string_literal: true
require_relative '../test_base'

module Client
  class OsImageTest < TestBase

    def self.id58_prefix
      '237'
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    multi_os_test '8A1',
    'start-files image_name<->os correspondence' do
      set_context
      assert_cyber_dojo_sh('cat /etc/issue')
      etc_issue = stdout
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
end
