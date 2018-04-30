require_relative '../../src/rack_dispatcher'
require_relative 'malformed_data'
require_relative 'rack_request_stub'
require_relative 'test_base'
require 'json'

class RackDispatcherTest < TestBase

  def self.hex_prefix
    'D06F7'
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
      assert_rack_call_exception('image_name:malformed', 'kata_new', {
        image_name:malformed,
        kata_id:kata_id
      }.to_json)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB3',
  %w( malformed kata_id becomes exception ) do
    malformed_kata_ids.each do |malformed|
      assert_rack_call_exception('kata_id:malformed', 'kata_new', {
        image_name:image_name,
        kata_id:malformed
      }.to_json)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB4',
  %w( malformed starting_files becomes exception ) do
    malformed_files.each do |malformed|
      assert_rack_call_exception('starting_files:malformed', 'avatar_new', {
        image_name:image_name,
        kata_id:kata_id,
        avatar_name:'salmon',
        starting_files:malformed
      }.to_json)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB5',
  %w( malformed avatar_name becomes exception ) do
    malformed_avatar_names.each do |malformed|
      assert_rack_call_exception('avatar_name:malformed', 'avatar_old', {
        image_name:image_name,
        kata_id:kata_id,
        avatar_name:malformed
      }.to_json)
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
      assert_rack_call_run_malformed({new_files:malformed})
      assert_rack_call_run_malformed({deleted_files:malformed})
      assert_rack_call_run_malformed({unchanged_files:malformed})
      assert_rack_call_run_malformed({changed_files:malformed})
    end
  end

  # - - - - - - - - - - - - - - - - -
  # sha
  # - - - - - - - - - - - - - - - - -

  test 'AB0', 'sha' do
    path_info = 'sha'
    env = { body:{}.to_json, path_info:path_info }
    code,json = rack_call(env)
    assert_equal 200, code
    assert_sha(json[path_info])
    assert_empty_log(json)
  end

  def assert_sha(string)
    assert_equal 40, string.size
    string.each_char do |ch|
      assert "0123456789abcdef".include?(ch)
    end
  end

  # - - - - - - - - - - - - - - - - -
  # kata_new
  # - - - - - - - - - - - - - - - - -

  test 'AB1', 'kata_new' do
    path_info = 'kata_new'
    env = {
      path_info:path_info,
      body: {
        image_name:image_name,
        kata_id:kata_id
      }.to_json
    }
    code,json = rack_call(env)
    assert_equal 200, code
    assert json.has_key?(path_info)
    assert_empty_log(json)
  end

  # - - - - - - - - - - - - - - - - -
  # kata_old
  # - - - - - - - - - - - - - - - - -

  test 'AB2', 'kata_old' do
    path_info = 'kata_old'
    env = {
      path_info:path_info,
      body: {
        image_name:image_name,
        kata_id:kata_id
      }.to_json
    }
    code,json = rack_call(env)
    assert_equal 200, code
    assert json.has_key?(path_info)
    assert_empty_log(json)
  end

  # - - - - - - - - - - - - - - - - -
  # avatar_new
  # - - - - - - - - - - - - - - - - -

  test 'AB3', 'avatar_new' do
    path_info = 'avatar_new'
    env = {
      path_info:path_info,
      body: {
        image_name:image_name,
        kata_id:kata_id,
        avatar_name:'salmon',
        starting_files:{}
      }.to_json
    }
    code,json = rack_call(env)
    assert_equal 200, code
    assert json.has_key?(path_info)
    assert_empty_log(json)
  end

  # - - - - - - - - - - - - - - - - -
  # avatar_old
  # - - - - - - - - - - - - - - - - -

  test 'AB4', 'avatar_old' do
    path_info = 'avatar_old'
    env = {
      path_info:path_info,
      body: {
        image_name:image_name,
        kata_id:kata_id,
        avatar_name:'salmon'
      }.to_json
    }
    code,json = rack_call(env)
    assert_equal 200, code
    assert json.has_key?(path_info)
    assert_empty_log(json)
  end

  # - - - - - - - - - - - - - - - - -
  # run_cyber_dojo_sh
  # - - - - - - - - - - - - - - - - -

  test 'AB9', '[C,assert] run_cyber_dojo_sh' do
    path_info = 'run_cyber_dojo_sh'
    args = {
      image_name:image_name,
      kata_id:kata_id,
      avatar_name:'salmon',
      new_files:starting_files,
      deleted_files:{},
      unchanged_files:{},
      changed_files:{},
      max_seconds:10
    }
    expected = {
      path_info => {
        stdout:'',
        stderr:gcc_assert_stderr,
        status:2,
        colour:'red'
      }
    }

    env = { path_info:path_info, body:args.to_json }
    triple = rack.call(env, external, RackRequestStub)
    assert_200(triple)
    assert_content_app_json(triple)

    # Careful here...
    # stderr may or may not have ' (core dumped)' appended.
    # Note that --ulimit core=0 is in place in the runner so
    # no core file is -actually- dumped.
    json = payload(triple)[path_info]
    # C,assert output is compiler-OS dependent. This is gcc,Debian
    assert_equal gcc_assert_stdout, json['stdout']
    assert json['stderr'].start_with?(gcc_assert_stderr), json['stderr']
    assert_equal 2, json['status']
    assert_equal 'red', json['colour']
  end

  private # = = = = = = = = = = = = =

  include MalformedData

  def assert_200(triple)
    assert_equal 200, triple[0]
  end

  def assert_content_app_json(triple)
    expected = { 'Content-Type' => 'application/json' }
    assert_equal(expected, triple[1])
  end

  def payload(triple)
    JSON.parse(triple[2][0])
  end

  def assert_empty_log(json)
    assert_equal [], json['log']
  end

  # - - - - - - - - - - - - - - - - -

  def assert_rack_call_run_malformed(added)
    expected = "#{added.keys[0]}:malformed"
    assert_rack_call_exception(expected, 'run_cyber_dojo_sh', {
      image_name:image_name,
      kata_id:kata_id,
      avatar_name:'salmon',
      new_files:{},
      deleted_files:{},
      unchanged_files:{},
      changed_files:{ 'cyber-dojo.sh' => 'pwd' },
      max_seconds:10
    }.merge(added).to_json)
  end

  # - - - - - - - - - - - - - - - - -

  def assert_rack_call_exception(expected, path_info, body)
    env = { path_info:path_info, body:body }

    triple = nil
    written = with_captured_stdout {
      triple = rack.call(env, external, RackRequestStub)
    }

    assert_equal 400, triple[0], written
    assert_content_app_json(triple)

    json = JSON.parse(triple[2][0])
    assert_equal expected, json['exception']
    refute_nil json['trace']
    #assert_equal [], external.log.messages
    assert_empty_log(json)

    out = JSON.parse(written)
    assert_equal expected, out['exception']
    assert_equal [], out['log']
    assert out['trace'].size > 10
  end

  # - - - - - - - - - - - - - - - - -

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
    "test: hiker.tests.c:7: life_the_universe_and_everything: Assertion `answer() == 42' failed.\n" +
    "make: *** [test.output] Aborted"
  end

  # - - - - - - - - - - - - - - - - -

  METHOD_NAMES = %w(
    sha
    kata_new kata_old
    avatar_new avatar_old
    run_cyber_dojo_sh
  )

  # - - - - - - - - - - - - - - - - -

  def rack
    RackDispatcher.new(cache)
  end

  def rack_call(env)
    triple = rack.call(env, external, RackRequestStub)
    code = triple[0]
    type = triple[1]
    json = JSON.parse(triple[2][0])

    expected_type = { 'Content-Type' => 'application/json' }
    assert_equal expected_type, type
    return code,json
  end

=begin
  def rack_call(method_name, args = {})
    args['image_name'] = image_name
    args['kata_id'] = kata_id
    env = { body:args.to_json, path_info:method_name.to_s }
    result = rack.call(env, external, RackRequestStub)
    @json = JSON.parse(result[2][0])
  end

  def assert_exception(expected)
    assert_equal expected, exception, result
    refute_nil trace
  end

  def exception
    @json[__method__.to_s]
  end

  def trace
    @json[__method__.to_s]
  end

  multi_os_test '4CC',
  %w( malformed avatar_name raises ) do
    written = with_captured_stdout {
      in_kata_as('salmon') {
        run_cyber_dojo_sh({ avatar_name: 'waterbottle' })
        assert_exception 'avatar_name:malformed'
      }
    }
    json = JSON.parse(written)
    assert_equal 'avatar_name:malformed', json['exception']
    assert_equal [], json['log']
    assert json['trace'].size > 10
    assert_equal [], external.log.messages
  end
=end

end
