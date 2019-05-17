require_relative '../src/rack_dispatcher'
require_relative 'bash_stub_raiser'
require_relative 'bash_stub_tar_pipe_out'
require_relative 'malformed_data'
require_relative 'rack_request_stub'
require_relative 'test_base'
require 'json'
require 'stringio'

class RackDispatcherTest < TestBase

  def self.hex_prefix
    'D06'
  end

  # - - - - - - - - - - - - - - - - -

  test 'BAF',
  %w( unknown method becomes exception ) do
    expected = 'json:malformed'
    assert_rack_call_exception(expected, nil,       '{}')
    assert_rack_call_exception(expected, [],        '{}')
    assert_rack_call_exception(expected, {},        '{}')
    assert_rack_call_exception(expected, true,      '{}')
    assert_rack_call_exception(expected, 42,        '{}')
    assert_rack_call_exception(expected, 'unknown', '{}')
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB0',
  %w( malformed json in http payload becomes exception ) do
    expected = 'json:malformed'
    METHOD_NAMES.each do |method_name|
      assert_rack_call_exception(expected, method_name, 'sdfsdf')
      assert_rack_call_exception(expected, method_name, 'nil')
      assert_rack_call_exception(expected, method_name, 'null')
      assert_rack_call_exception(expected, method_name, '[]')
      assert_rack_call_exception(expected, method_name, 'true')
      assert_rack_call_exception(expected, method_name, '42')
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB2',
  %w( malformed image_name becomes exception ) do
    malformed_image_names.each do |malformed|
      assert_rack_call_exception(
        'image_name:malformed',
        'run_cyber_dojo_sh',
        run_cyber_dojo_sh_args.merge({image_name:malformed}).to_json
      )
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB3',
  %w( malformed id becomes exception ) do
    malformed_ids.each do |malformed|
      assert_rack_call_exception(
        'id:malformed',
        'run_cyber_dojo_sh',
        run_cyber_dojo_sh_args.merge({id:malformed}).to_json
      )
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB7',
  %w( malformed max_seconds becomes exception ) do
    malformed_max_seconds.each do |malformed|
      assert_rack_call_run_malformed({max_seconds:malformed})
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB8',
  %w( malformed files becomes exception ) do
    malformed_files.each do |malformed|
      assert_rack_call_run_malformed({files:malformed})
    end
  end

  # - - - - - - - - - - - - - - - - -
  # ready?
  # - - - - - - - - - - - - - - - - -

  test 'A9E', 'its ready' do
    path_info = 'ready'
    env = { body:{}.to_json, path_info:path_info }
    rack_call(env)
    assert_200
    assert_equal true, JSON.parse(@body)[path_info+'?']
    refute_body_contains('exception')
    refute_body_contains('trace')
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -
  # sha
  # - - - - - - - - - - - - - - - - -

  test 'AB0', 'sha' do
    path_info = 'sha'
    env = { body:{}.to_json, path_info:path_info }
    rack_call(env)
    assert_200
    assert_sha(JSON.parse(@body)[path_info])
    refute_body_contains('exception')
    refute_body_contains('trace')
    assert_nothing_logged
  end

  def assert_sha(string)
    assert_equal 40, string.size
    string.each_char do |ch|
      assert '0123456789abcdef'.include?(ch)
    end
  end

  # - - - - - - - - - - - - - - - - -
  # run_cyber_dojo_sh
  # - - - - - - - - - - - - - - - - -

  test 'AB5', '[C,assert] run_cyber_dojo_sh with no logging' do
    path_info = 'run_cyber_dojo_sh'
    args = run_cyber_dojo_sh_args
    env = { path_info:path_info, body:args.to_json }
    rack_call(env)

    assert_200
    assert_body_contains(path_info)
    refute_body_contains('exception')
    refute_body_contains('trace')
    #assert_nothing_logged
    # on CircleCI I get...
    # "stderr": "WARNING: Your kernel does not support swap limit
    #            capabilities or the cgroup is not mounted.
    #            Memory limited without swap"
    assert_gcc_starting_red
  end

  # - - - - - - - - - - - - - - - - -

  test 'AB6', '[C,assert] run_cyber_dojo_sh with some logging' do
    path_info = 'run_cyber_dojo_sh'
    args = run_cyber_dojo_sh_args
    env = { path_info:path_info, body:args.to_json }
    stub = BashStubTarPipeOut.new('fail')
    rack_call(env, External.new({ 'bash' => stub }))

    assert stub.fired_once?
    assert_200
    assert_body_contains(path_info)
    refute_body_contains('exception')
    refute_body_contains('backtrace')

    #assert_log_contains('command')
    #assert_log_contains('stdout', 'fail')
    #assert_log_contains('stderr', '')
    #assert_log_contains('status', 1)
    assert_gcc_starting_red
  end

  # - - - - - - - - - - - - - - - - -

  test 'AB7', 'server error results in 500 status response' do
    path_info = 'run_cyber_dojo_sh'
    args = run_cyber_dojo_sh_args
    env = { path_info:path_info, body:args.to_json }
    raiser = BashStubRaiser.new('fubar')
    external = External.new({ 'bash' => raiser })
    runner = Runner.new(external)
    rack = RackDispatcher.new(runner)
    with_captured_stdout_stderr {
      response = rack.call(env, RackRequestStub)
      assert raiser.fired_once?
      status = response[0]
      assert_equal 500, status
    }
  end

  private # = = = = = = = = = = = = =

  def assert_rack_call_run_malformed(added)
    expected = "#{added.keys[0]}:malformed"
    args = run_cyber_dojo_sh_args.merge(added).to_json
    assert_rack_call_exception(expected, 'run_cyber_dojo_sh', args)
  end

  # - - - - - - - - - - - - - - - - -

  def assert_rack_call_exception(expected, path_info, body)
    env = { path_info:path_info, body:body }
    rack_call(env)
    assert_400

    [@body, @stderr].each do |s|
      refute_nil s
      json = JSON.parse(s)
      ex = json['exception']
      refute_nil ex
      assert_equal 'RunnerStatelessService', ex['class']
      assert_equal expected, ex['message']
      assert_equal 'Array', ex['backtrace'].class.name
    end
  end

  # - - - - - - - - - - - - - - - - -

  def rack_call(env, e = external)
    runner = Runner.new(e)
    rack = RackDispatcher.new(runner)
    response = with_captured_stdout_stderr {
      rack.call(env, RackRequestStub)
    }
    @status = response[0]
    @type = response[1]
    @body = response[2][0]

    expected_type = { 'Content-Type' => 'application/json' }
    assert_equal expected_type, @type
  end

  def with_captured_stdout_stderr
    begin
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = StringIO.new('', 'w')
      $stderr = StringIO.new('', 'w')
      response = yield
      @stderr = $stderr.string
      @stdout = $stdout.string
      response
    ensure
      $stderr = old_stderr
      $stdout = old_stdout
    end
  end

  # - - - - - - - - - - - - - - - - -

  def assert_200
    assert_equal 200, @status
  end

  def assert_400
    assert_equal 400, @status
  end

  # - - - - - - - - - - - - - - - - -

  def assert_body_contains(key)
    refute_nil @body
    json = JSON.parse(@body)
    assert json.has_key?(key)
  end

  def refute_body_contains(key)
    refute_nil @body
    json = JSON.parse(@body)
    refute json.has_key?(key)
  end

  # - - - - - - - - - - - - - - - - -

  def assert_nothing_logged
    assert_equal '', @stdout
    assert_equal '', @stderr
  end

  # - - - - - - - - - - - - - - - - -

  def assert_gcc_starting_red
    result = JSON.parse(@body)['run_cyber_dojo_sh']
    stdout = result['stdout']
    assert_equal gcc_assert_stdout, stdout['content'], stdout
    stderr = result['stderr']
    assert stderr['content'].start_with?(gcc_assert_stderr), stderr
    assert_equal 2, result['status']
    assert_equal 'red', result['colour']
  end

  def gcc_assert_stdout
    # gcc,Debian
    "makefile:14: recipe for target 'test.output' failed\n"
  end

  def gcc_assert_stderr
    # This depends partly on the host-OS. For example, when
    # the host-OS is CoreLinux (in the boot2docker VM
    # in DockerToolbox for Mac) then the output ends
    # ...Aborted (core dumped).
    # But if the host-OS is Debian/Ubuntu (eg on Travis)
    # then the output does not say "(core dumped)"
    # Note that --ulimit core=0 is in place in the runner so
    # no core file is -actually- dumped.
    "test: hiker.tests.c:7: life_the_universe_and_everything: Assertion `answer() == 42' failed.\n" +
    "make: *** [test.output] Aborted"
  end

  # - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh_args
    {
      image_name:image_name,
      id:id,
      files:starting_files,
      max_seconds:10
    }
  end

  # - - - - - - - - - - - - - - - - -

  METHOD_NAMES = %w(
    sha
    run_cyber_dojo_sh
  )

  include MalformedData

end
