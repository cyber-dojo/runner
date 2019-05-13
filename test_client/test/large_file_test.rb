require_relative 'test_base'

class LargeFileTest < TestBase

  def self.hex_prefix
    '46D'
  end

  multi_os_test '3DB',
  'run with very large file is red' do
    # Notes
    # 1. docker-compose.yml need a tmpfs for this to pass
    #      tmpfs: /tmp
    # 2. If the tar-file coming *out* of the container
    #    (to support approval style test frameworks)
    #    is not compressed (tar -zcf) then this fails.
    run_cyber_dojo_sh({
      created_files: { 'big_file' => file('X'*1023*500) }
    })
    assert red?, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'ED4',
  'stdout greater than 25K is truncated' do
    # [1] fold limit is 10000 so I do five smaller folds
    five_K_plus_1 = 5*1024+1
    command = [
      'cat /dev/urandom',
      "tr -dc 'a-zA-Z0-9'",
      "fold -w #{five_K_plus_1}", # [1]
      'head -n 1'
    ].join('|')
    run_cyber_dojo_sh({
      changed_files: {
        'cyber-dojo.sh' => file("seq 5 | xargs -I{} sh -c '#{command}'")
      }
    })
    assert result['stdout']['truncated']
  end

end
