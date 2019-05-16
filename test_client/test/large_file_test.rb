require_relative 'test_base'

class LargeFileTest < TestBase

  def self.hex_prefix
    '46D'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '3DB',
  'run with very large file is red' do
    # Notes
    # 1. docker-compose.yml need a tmpfs for this to pass
    #      tmpfs: /tmp
    # 2. If the tar-file coming *out* of the container
    #    (to support approval style test frameworks)
    #    is not compressed (tar -zcf) then this fails.
    run_cyber_dojo_sh({
      created_files: { 'big_file' => intact('X'*1023*500) }
    })
    assert red?, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'ED4',
  'stdout greater than 50K is truncated' do
    script = "od -An -x /dev/urandom | head -c#{51*1024}"
    run_cyber_dojo_sh({
      changed_files: {
        'cyber-dojo.sh' => intact(script)
      }
    })
    assert result['stdout']['truncated']
  end

end
