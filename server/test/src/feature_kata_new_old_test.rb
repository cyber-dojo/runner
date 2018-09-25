require_relative 'test_base'

class KataNewOldTest < TestBase

  def self.hex_prefix
    '20A7A'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'DBC', %w( resurrection requires kata_new to work after kata_old ) do
    kata_new
    kata_old
    kata_new
    kata_old
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'DBD', %w( kata_new is idempotent only if runner is stateless ) do
    # :nocov:
    if stateless?
      kata_new
      kata_new
    else
      kata_new
      begin
        error = assert_raises(StandardError) { kata_new }
        assert_equal 'kata_id:exists', error.message
      ensure
        kata_old
      end
    end
    # :nocov:
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'DBE', %w( kata_old is idempotent only if runner is stateless ) do
    # :nocov:
    if stateless?
      kata_old
      kata_old
    else
      kata_new
      kata_old
      error = assert_raises(StandardError) { kata_old }
      assert_equal 'kata_id:!exists', error.message
    end
    # :nocov:
  end

  private

  def stateless?
    result = nil
    in_kata {
      cmd = 'printenv CYBER_DOJO_RUNNER'
      result = assert_cyber_dojo_sh(cmd) == 'stateless'
    }
    result
  end

end
