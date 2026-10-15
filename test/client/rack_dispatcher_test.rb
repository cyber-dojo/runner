require_relative '../test_base'
require_code 'rack_dispatcher'
require 'json'

class RackDispatcherTest < TestBase

  test 'Ck7Ra1', %w[
    GET /alive
    returns 200 and alive? true
  ] do
    assert_equal [200, { 'alive?' => true }], rack_call('alive')
  end

  test 'Ck7Ra2', %w[
    GET /ready
    returns 200 and ready? true
  ] do
    assert_equal [200, { 'ready?' => true }], rack_call('ready')
  end

  test 'Ck7Ra3', %w[
    GET of an unknown path
    returns 400 naming the path
  ] do
    expected = { 'exception' => { 'path' => '/xyz', 'message' => 'unknown path' } }
    assert_equal [400, expected], rack_call('xyz')
  end

  private

  def rack_call(path_info)
    set_context
    rack = RackDispatcher.new(context)
    status, headers, body = rack.call({ path_info: path_info }, RackRequestStub)
    assert_equal({ 'Content-Type' => 'application/json' }, headers)
    [status, JSON.parse(body[0])]
  end
end
