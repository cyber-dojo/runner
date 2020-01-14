require_relative 'test_base'

class RunCyberDojoShTest < TestBase

  def self.hex_prefix
    '14D'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '2F5',
  'call to existing method with bad argument type becomes RunnerService::Error' do
    error = assert_raises(Runner::Error) {
      with_captured_stdout {
        run_cyber_dojo_sh({ max_seconds:'xxx' })
      }
    }
    json = JSON.parse(error.message)
    assert_equal '/run_cyber_dojo_sh', json['path']
    assert_equal 'RunnerService', json['class']
  end

  private

  def with_captured_stdout
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('', 'w')
      yield
    ensure
      $stdout = old_stdout
    end
  end

end
