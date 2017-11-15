require_relative 'test_base'

class ApiNoOpTest < TestBase

  def self.hex_prefix
    '4F725'
  end

  multi_os_test 'D87',
  %w( kata_new/kata_old are no-ops for API compatibility ) do
    assert_no_op 'kata_new'
    assert_no_op 'kata_old'
  end

  multi_os_test 'D08',
  %w( avatar_new/avatar_old are no-ops for API compatibility ) do
    in_kata {
      assert_no_op 'avatar_new'
      assert_no_op 'avatar_old'
    }
  end

  def assert_no_op(method_name)
    result = self.send method_name
    assert_equal({}, result, method_name)
  end

end
