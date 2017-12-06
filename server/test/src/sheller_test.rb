require_relative 'test_base'

class ShellerTest < TestBase

  def self.hex_prefix
    'C894D'
  end

  # - - - - - - - - - - - - - - - - -

  test '247',
  %w( when assert(cmd) has zero status, stdout is returned ) do
    stdout = shell.assert('printf Hello')
    assert_equal 'Hello', stdout
  end

  # - - - - - - - - - - - - - - - - -

  test '248',
  %w( when assert(cmd) is non-zero,
      exception is raised,
      the exception info is put in the ledger
  ) do
    error = assert_raises(ShellerError) {
      shell.assert('printf Hello && false')
    }
    assert_equal({
        command:'printf Hello && false',
        stdout:'Hello',
        stderr:'',
        status:1
      }, error.args
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '246',
  %w( when assert(cmd) raises
      the exception info is put in the ledger
  ) do
    error = assert_raises(ShellerError) {
      shell.assert('xxx Hello')
    }
    assert_equal({
      command:'xxx Hello',
      message:'No such file or directory - xxx'
      }, error.args
    )
  end

end
