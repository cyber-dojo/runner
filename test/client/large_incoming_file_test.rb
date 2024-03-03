require_relative '../test_base'

class LargeIncomingFileTest < TestBase
  def self.id58_prefix
    '46D'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '3DB',
       'large incoming file' do
    # Notes
    # 1. docker-compose.yml need a tmpfs for this to pass
    #      tmpfs: /tmp
    # 2. If the tar-file coming *out* of the container
    #    (to support approval style test frameworks)
    #    is not compressed (tar -zcf) then this fails.
    set_context
    filename = 'big_file'
    run_cyber_dojo_sh({
                        created_files: { filename => 'X' * 1023 * 500 }
                      })
    refute timed_out?, run_result
  end
end
