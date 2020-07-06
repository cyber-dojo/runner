# frozen_string_literal: true
require_relative 'test_base'
require_source 'rack_dispatcher'
require 'json'

class RackDispatcherTest < TestBase

  def self.id58_prefix
    'D06'
  end

  # = = = = = = = = = = = = = = = = =
  # 200
  # = = = = = = = = = = = = = = = = =

  test '82d', %w(
  allow '' instead of {} to allow kubernetes
  liveness/readyness http probes ) do
    rack_call(body:'', path_info:'ready')
    ready = assert_200('ready?')
    assert ready.is_a?(TrueClass)
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  test 'AB0', 'sha' do
    rack_call({ body:{}.to_json, path_info:'sha' })
    sha = assert_200('sha')
    assert_sha(sha)
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  test '15D', 'alive' do
    rack_call({ body:{}.to_json, path_info:'alive' })
    alive = assert_200('alive?')
    assert alive.is_a?(TrueClass)
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  test 'A9E', 'ready' do
    rack_call({ body:{}.to_json, path_info:'ready' })
    ready = assert_200('ready?')
    assert ready.is_a?(TrueClass)
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test 'AB5', 'run_cyber_dojo_sh 200' do
    args = run_cyber_dojo_sh_args
    rack_call(path_info:'run_cyber_dojo_sh', body:args.to_json)
    assert_200('run_cyber_dojo_sh')
    assert_gcc_starting
    message = 'Read red-amber-green lambda for cyberdojofoundation/gcc_assert'
    assert_logged(message)
  end

  # - - - - - - - - - - - - - - - - -

  test 'A9F', 'pull_image' do
    args = { id:id58, image_name:image_name }
    rack_call(path_info:'pull_image', body:args.to_json)
    assert_equal 'pulling', assert_200('pull_image')
  end

  # = = = = = = = = = = = = = = = = =
  # 400
  # = = = = = = = = = = = = = = = = =

  test 'BB0',
  %w( malformed json in http payload becomes 400 exception ) do
    expected = 'body is not JSON'
    METHOD_NAMES.each do |method_name|
      assert_rack_call_400_exception(expected, method_name, 'sdfsdf')
      assert_rack_call_400_exception(expected, method_name, 'nil')
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB1',
  %w( json not Hash in http payload becomes 400 exception ) do
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
  %w( unknown path becomes 400 exception ) do
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
  %w( missing argument becomes 400 exception ) do
    f = 'run_cyber_dojo_sh'
    assert_rack_call_400_exception('missing argument: :id', f, {files:{},manifest:{}}.to_json)
    assert_rack_call_400_exception('missing argument: :files', f, {id:{},manifest:{}}.to_json)
    assert_rack_call_400_exception('missing argument: :manifest', f, {id:{},files:{}}.to_json)
  end

  test 'AA7',
  %w( missing arguments becomes 400 exception ) do
    f = 'run_cyber_dojo_sh'
    assert_rack_call_400_exception('missing arguments: :id, :files', f, {manifest:{}}.to_json)
    assert_rack_call_400_exception('missing arguments: :id, :manifest', f, {files:{}}.to_json)
    assert_rack_call_400_exception('missing arguments: :files, :manifest', f, {id:{}}.to_json)
  end

  # - - - - - - - - - - - - - - - - -

  test 'AA8',
  %w( unknown argument becomes 400 exception ) do
    assert_rack_call_400_exception('unknown argument: :x', 'sha', {x:{}}.to_json)
    assert_rack_call_400_exception('unknown argument: :y', 'alive', {y:{}}.to_json)
    assert_rack_call_400_exception('unknown argument: :z', 'ready', {z:{}}.to_json)
  end

  test 'AA9',
  %w( unknown arguments becomes 400 exception ) do
    assert_rack_call_400_exception('unknown arguments: :x, :y', 'sha', {x:{},y:{}}.to_json)
    assert_rack_call_400_exception('unknown arguments: :a, :q, :b', 'alive', {a:{},q:{},b:{}}.to_json)
  end

  # = = = = = = = = = = = = = = = = =
  # 500
  # = = = = = = = = = = = = = = = = =

  test 'AB7', 'server error in RackDispatcher results in 500 status response' do
    path_info = 'run_cyber_dojo_sh'
    body = run_cyber_dojo_sh_args.to_json
    env = { path_info:path_info, body:body }
    response = rack_call(env, nil)
    status = response[0]
    assert_equal 500, status
  end

  # - - - - - - - - - - - - - - - - -

  test 'AB8', 'server error in Dispatcher results in 500 status response' do
    context = Context.new(process:{}, logger:LoggerSpy.new)
    rack = RackDispatcher.new(context)
    path_info = 'run_cyber_dojo_sh'
    body = run_cyber_dojo_sh_args.to_json
    env = { path_info:path_info, body:body }
    response = rack.call(env)
    status = response[0]
    assert_equal 500, status
  end

  private

  def assert_rack_call_400_exception(expected, path_info, body)
    env = { path_info:path_info, body:body }
    rack_call(env)
    assert_400
    log = @options[:logger].logged
    [response_body,log].each do |s|
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

  def rack_call(env, klass = RackRequestStub)
    @options = { logger:LoggerSpy.new }
    context = Context.new(@options)
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
    assert_equal '', @options[:logger].logged
  end

  def assert_logged(message)
    log = @options[:logger].logged
    logged_count = log.lines.count { |line| line.include?(message) }
    assert_equal 1, logged_count, ":#{log}:"
  end

  # - - - - - - - - - - - - - - - - -

  def assert_gcc_starting
    result = JSON.parse(response_body)['run_cyber_dojo_sh']
    stdout = result['stdout']['content']
    diagnostic = 'stdout is not empty!'
    assert_equal '', stdout, diagnostic
    stderr = result['stderr']['content']
    assert_assertion_failed(stderr)
    assert_makefile_aborted(stderr)
    assert_equal '2', result['status'], :status
  end

  def assert_assertion_failed(stderr)
    r = /test: hiker.tests.c:(\d+): life_the_universe_and_everything: Assertion `answer\(\) == 42' failed./
    diagnostic = "Expected stderr to match #{r.to_s}\nstderr:#{stderr}"
    assert r.match(stderr), diagnostic
  end

  def assert_makefile_aborted(stderr)
    # This depends partly on the host-OS. For example, when
    # the host-OS is CoreLinux (in the boot2docker VM
    # in DockerToolbox for Mac) then the output ends
    # ...Aborted (core dumped).
    # But if the host-OS is Debian/Ubuntu (eg on Travis)
    # then the output does not say "(core dumped)" at the end.
    # Note that --ulimit core=0 is in place in the runner so
    # no core file is -actually- dumped.
    r = /make: \*\*\* \[makefile:(\d+): test.output\] Aborted/
    diagnostic = "Expected stderr to match #{r.to_s}\nstderr:#{stderr}"
    assert r.match(stderr), diagnostic
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

  METHOD_NAMES = %w(
    sha
    ready
    run_cyber_dojo_sh
  )

end
