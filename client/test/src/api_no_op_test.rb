require_relative 'test_base'

class ApiNoOpTest < TestBase

  def self.hex_prefix
    '4F7'
  end

  multi_os_test 'D87',
  %w( kata_new/kata_old are no-ops for API compatibility ) do
    assert_no_op 'kata_new'
    assert_no_op 'kata_old'
  end

  def assert_no_op(method_name)
    result = self.send method_name
    assert_nil result, method_name
  end

end
