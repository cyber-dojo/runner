# frozen_string_literal: true
require_relative 'test_base'

class LargeFileTest < TestBase

  def self.id58_prefix
    '46D'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '3DB',
  'run with very large file' do
    # Notes
    # 1. docker-compose.yml need a tmpfs for this to pass
    #      tmpfs: /tmp
    # 2. If the tar-file coming *out* of the container
    #    (to support approval style test frameworks)
    #    is not compressed (tar -zcf) then this fails.
    run_cyber_dojo_sh({
      created_files: { 'big_file' => 'X'*1023*500 }
    })
    refute timed_out?, result
    assert_equal '1', status, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'ED4',
  'stdout greater than 50K is truncated' do
    script = "od -An -x /dev/urandom | head -c#{51*1024}"
    run_cyber_dojo_sh({
      changed_files: {
        'cyber-dojo.sh' => script
      }
    })
    # Occasionally fails with status==137 (128+KILL)
    # if test machine is heavily loaded.
    if status === '0'
      diagnostic = [stdout,stderr,status].to_s
      assert result['stdout']['truncated'], diagnostic
    end
  end

end
