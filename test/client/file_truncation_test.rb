# frozen_string_literal: true
require_relative '../test_base'

module Client
  class FileTruncationTest < TestBase

    def self.id58_prefix
      'E4A'
    end

    # - - - - - - - - - - - - - - - - -

    multi_os_test '52A',
    %w( generated text files bigger than 50K are truncated ) do
      set_context
      filename = 'large_file.txt'
      script = "od -An -x /dev/urandom | head -c#{51*1024} > #{filename}"
      script += ';'
      script += "stat -c%s #{filename}"

      assert_cyber_dojo_sh(script)

      assert_equal "#{51*1024}\n", stdout, :stdout_size
      assert_equal [filename], created.keys
      assert created[filename]['truncated'].is_a?(TrueClass), :truncated
      assert_equal 50*1024, created[filename]['content'].size, :size
      assert_equal([], deleted, :deleted)
      assert_equal({}, changed, :changed)
    end

    # - - - - - - - - - - - - - - - - -

    test '52B',
    %w( stdout and stderr are truncated to 50K ) do
      set_context
      script = [
        "od -An -x /dev/urandom | head -c#{51*1024} > /tmp/stdout",
        "od -An -x /dev/urandom | head -c#{51*1024} > /tmp/stderr",
        "cat /tmp/stdout",
        "1>&2 cat /tmp/stderr"
      ].join(';')

      assert_cyber_dojo_sh(script)

      assert_equal 50*1024, stdout.size, :stdout_content_is_truncated
      assert run_result['stdout']['truncated'].is_a?(TrueClass), :stdout_truncated_property_is_true
      assert_equal 50*1024, stderr.size, :stderr_content_is_truncated
      assert run_result['stderr']['truncated'].is_a?(TrueClass), :stderr_truncated_property_is_true
    end

  end
end
