require_relative '../test_base'
require_code 'rack_dispatcher'
require 'json'

class RackDispatcherTest < TestBase
  def self.id58_prefix
    'D06'
  end

  # = = = = = = = = = = = = = = = = =
  # 200
  # = = = = = = = = = = = = = = = = =

  test '82d', %w[
    allow '' instead of {} to allow kubernetes
    liveness/readyness http probes
  ] do
    env = { body: '', path_info: 'ready' }
    rack_call(env)
    ready = assert_200('ready?')
    assert ready.is_a?(TrueClass)
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  test '15D', 'alive' do
    env = { body: {}.to_json, path_info: 'alive' }
    rack_call(env)
    alive = assert_200('alive?')
    assert alive.is_a?(TrueClass)
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  test 'A9E', 'ready' do
    env = { body: {}.to_json, path_info: 'ready' }
    rack_call(env)
    ready = assert_200('ready?')
    assert ready.is_a?(TrueClass)
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  test 'AB0', 'sha' do
    env = { body: {}.to_json, path_info: 'sha' }
    rack_call(env)
    sha = assert_200('sha')
    assert_sha(sha)
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test 'AB5', 'run_cyber_dojo_sh 200' do
    args = run_cyber_dojo_sh_args
    env = { path_info: 'run_cyber_dojo_sh', body: args.to_json }
    rack_call(env, runner: dummy = RunnerDummy.new)
    assert_200('run_cyber_dojo_sh')
    assert dummy.called?
  end

  class RunnerDummy
    def initialize
      @called = false
    end

    def run_cyber_dojo_sh(id:, files:, manifest:)
      @called = true
    end

    def called?
      @called
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'A9F', 'pull_image' do
    args = { id: id58, image_name: image_name }
    env = { path_info: 'pull_image', body: args.to_json }
    rack_call(env, puller: dummy = PullerDummy.new)
    assert_200('pull_image')
    assert dummy.called?
  end

  class PullerDummy
    def initialize
      @called = false
    end

    def pull_image(id:, image_name:)
      @called = true
    end

    def called?
      @called
    end
  end

  # = = = = = = = = = = = = = = = = =
  # 400
  # = = = = = = = = = = = = = = = = =

  test 'BB0',
       %w[malformed json in http payload becomes 400 exception] do
    expected = 'body is not JSON'
    METHOD_NAMES.each do |method_name|
      assert_rack_call_400_exception(expected, method_name, 'sdfsdf')
      assert_rack_call_400_exception(expected, method_name, 'nil')
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB1',
       %w[json not Hash in http payload becomes 400 exception] do
    expected = 'body is not JSON Hash'
    METHOD_NAMES.each do |method_name|
      assert_rack_call_400_exception(expected, method_name, 'null')
      assert_rack_call_400_exception(expected, method_name, '[]')
      assert_rack_call_400_exception(expected, method_name, 'true')
      assert_rack_call_400_exception(expected, method_name, '42')
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB2',
       %w[unknown path becomes 400 exception] do
    expected = 'unknown path'
    assert_rack_call_400_exception(expected, nil,       '{}')
    assert_rack_call_400_exception(expected, [],        '{}')
    assert_rack_call_400_exception(expected, {},        '{}')
    assert_rack_call_400_exception(expected, true,      '{}')
    assert_rack_call_400_exception(expected, 42,        '{}')
    assert_rack_call_400_exception(expected, 'unknown', '{}')
  end

  # - - - - - - - - - - - - - - - - -

  test 'AA6',
       %w[missing argument becomes 400 exception] do
    f = 'run_cyber_dojo_sh'
    assert_rack_call_400_exception('missing argument: :id', f, { files: {}, manifest: {} }.to_json)
    assert_rack_call_400_exception('missing argument: :files', f, { id: {}, manifest: {} }.to_json)
    assert_rack_call_400_exception('missing argument: :manifest', f, { id: {}, files: {} }.to_json)
  end

  test 'AA7',
       %w[missing arguments becomes 400 exception] do
    f = 'run_cyber_dojo_sh'
    assert_rack_call_400_exception('missing arguments: :id, :files', f, { manifest: {} }.to_json)
    assert_rack_call_400_exception('missing arguments: :id, :manifest', f, { files: {} }.to_json)
    assert_rack_call_400_exception('missing arguments: :files, :manifest', f, { id: {} }.to_json)
  end

  # - - - - - - - - - - - - - - - - -

  test 'AA8',
       %w[unknown arguments becomes 500 exception] do
    assert_rack_call_500_exception('wrong number of arguments (given 1, expected 0)', 'sha', { x: {} }.to_json)
    assert_rack_call_500_exception('wrong number of arguments (given 1, expected 0)', 'sha', { x: {}, y: {} }.to_json)
    # assert_rack_call_400_exception('unknown argument: :y', 'alive', {y:{}}.to_json)
    # assert_rack_call_400_exception('unknown argument: :z', 'ready', {z:{}}.to_json)
    # assert_rack_call_400_exception('unknown arguments: :a, :q, :b', 'alive', {a:{},q:{},b:{}}.to_json)
  end

  # = = = = = = = = = = = = = = = = =
  # 500
  # = = = = = = = = = = = = = = = = =

  test 'AB7', 'server error in RackDispatcher results in 500 status response' do
    path_info = 'run_cyber_dojo_sh'
    body = run_cyber_dojo_sh_args.to_json
    env = { path_info: path_info, body: body, klass: {} }
    response = rack_call(env)
    status = response[0]
    assert_equal 500, status
  end

  # - - - - - - - - - - - - - - - - -

  test 'AB8', 'server error in Dispatcher results in 500 status response' do
    context = Context.new(process: {}, logger: StdoutLoggerSpy.new)
    rack = RackDispatcher.new(context)
    path_info = 'run_cyber_dojo_sh'
    body = run_cyber_dojo_sh_args.to_json
    env = { path_info: path_info, body: body }
    response = rack.call(env)
    status = response[0]
    assert_equal 500, status
  end

  private

  def assert_rack_call_400_exception(expected, path_info, body)
    assert_rack_call_exception(expected, path_info, body)
    assert_400
  end

  def assert_rack_call_500_exception(expected, path_info, body)
    assert_rack_call_exception(expected, path_info, body)
    assert_500
  end

  def assert_rack_call_exception(expected, path_info, body)
    env = { path_info: path_info, body: body }
    rack_call(env)
    [response_body, log].each do |s|
      refute_nil s
      json = JSON.parse(s)
      ex = json['exception']
      refute_nil ex
      assert_equal 'Runner', ex['class']
      assert_equal expected, ex['message']
      assert_equal 'Array', ex['backtrace'].class.name
    end
  end

  # - - - - - - - - - - - - - - - - -

  def rack_call(env, options = { logger: StdoutLoggerSpy.new })
    klass = env.delete(:klass) || RackRequestStub
    set_context(options)
    rack = RackDispatcher.new(context)
    @response = rack.call(env, klass)
    expected_type = { 'Content-Type' => 'application/json' }
    actual_type = @response[1]
    assert_equal expected_type, actual_type, @response
    @response
  end

  def response_status
    @response[0]
  end

  def response_body
    @response[2][0]
  end

  # - - - - - - - - - - - - - - - - -

  def assert_200(name)
    assert_equal 200, response_status, @response
    assert_body_contains(name)
    refute_body_contains('exception')
    refute_body_contains('trace')
    JSON.parse(response_body)[name]
  end

  def assert_400
    assert_equal 400, response_status, @response
  end

  def assert_500
    assert_equal 500, response_status, @response
  end

  # - - - - - - - - - - - - - - - - -

  def assert_body_contains(key)
    refute_nil response_body, 'response body is nil'
    json = JSON.parse(response_body)
    assert json.has_key?(key), "assert json.has_key?(#{key}) keys are #{json.keys}"
  end

  def refute_body_contains(key)
    refute_nil response_body, 'respose body is nil'
    json = JSON.parse(response_body)
    refute json.has_key?(key), "refute json.has_key?(#{key}) keys are #{json.keys}"
  end

  # - - - - - - - - - - - - - - - - -

  def assert_nothing_logged
    assert_equal '', context.logger.logged
  end

  # - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh_args
    {
      'id' => id,
      'files' => starting_files,
      'manifest' =>
      {
        'image_name' => image_name,
        'max_seconds' => 10
      }
    }
  end

  # - - - - - - - - - - - - - - - - -

  METHOD_NAMES = %w[
    sha
    ready
    run_cyber_dojo_sh
  ]
end
