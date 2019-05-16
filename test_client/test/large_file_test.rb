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
    letters = [*('a'..'z')]
    size = 50 # -1 for yes's newline
    s = (size-1).times.map{letters[rand(letters.size)]}.join
    command = "yes '#{s}' | head -n 1025"
    run_cyber_dojo_sh({
      changed_files: {
        'cyber-dojo.sh' => intact(command)
      }
    })
    assert result['stdout']['truncated']
  end

end
