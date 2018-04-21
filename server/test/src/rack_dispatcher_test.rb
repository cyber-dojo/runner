require_relative '../../src/external'
require_relative '../../src/rack_dispatcher'
require_relative '../../src/runner'
require_relative 'image_names'
require_relative 'rack_request_stub'
require_relative 'test_base'

class RackDispatcherTest < TestBase

  def self.hex_prefix
    'D06F7'
  end

  # - - - - - - - - - - - - - - - - -

  test 'BAF',
  %w( unknown method becomes exception ) do
    assert_rack_call_raw(nil,       '{}', { exception:'json:malformed' })
    assert_rack_call_raw([],        '{}', { exception:'json:malformed' })
    assert_rack_call_raw({},        '{}', { exception:'json:malformed' })
    assert_rack_call_raw(true,      '{}', { exception:'json:malformed' })
    assert_rack_call_raw(42,        '{}', { exception:'json:malformed' })
    assert_rack_call_raw('unknown', '{}', { exception:'json:malformed' })
  end

  # - - - - - - - - - - - - - - - - -

  METHOD_NAMES = %w(
    kata_new Kata_old
    avatar_new avatar_old
    run_cyber_dojo_sh
  )

  test 'BB0',
  %w( malformed json in http payload becomes exception ) do
    METHOD_NAMES.each do |method_name|
      assert_rack_call_raw(method_name, 'sdfsdf', { exception:'json:malformed' })
      assert_rack_call_raw(method_name, 'nil',    { exception:'json:malformed' })
      assert_rack_call_raw(method_name, 'null',   { exception:'json:malformed' })
      assert_rack_call_raw(method_name, nil,      { exception:'json:malformed' })
      assert_rack_call_raw(method_name, [],       { exception:'json:malformed' })
      assert_rack_call_raw(method_name, {},       { exception:'json:malformed' })
      assert_rack_call_raw(method_name, true,     { exception:'json:malformed' })
      assert_rack_call_raw(method_name, 42,       { exception:'json:malformed' })
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB2',
  %w( malformed image_name becomes exception ) do
    malformed_image_names.each do |malformed|
      assert_rack_call_raw('kata_new', {
          image_name:malformed,
          kata_id:kata_id
        }.to_json, {
          exception:'image_name:malformed'
        }
      )
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB3',
  %w( malformed kata_id becomes exception ) do
    malformed_kata_ids.each do |malformed|
      assert_rack_call_raw('kata_new', {
          image_name:image_name,
          kata_id:malformed
        }.to_json, {
          exception:'kata_id:malformed'
        }
      )
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB4',
  %w( malformed starting_files becomes exception ) do
    malformed_files.each do |malformed|
      assert_rack_call_raw('avatar_new', {
          image_name:image_name,
          kata_id:kata_id,
          avatar_name:'salmon',
          starting_files:malformed
        }.to_json, {
          exception:'starting_files:malformed'
        }
      )
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB5',
  %w( malformed avatar_name becomes exception ) do
    malformed_avatar_names.each do |malformed|
      assert_rack_call_raw('avatar_old', {
          image_name:image_name,
          kata_id:kata_id,
          avatar_name:malformed
        }.to_json, {
          exception:'avatar_name:malformed'
        }
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
      assert_rack_call_run_malformed({new_files:malformed})
      assert_rack_call_run_malformed({deleted_files:malformed})
      assert_rack_call_run_malformed({unchanged_files:malformed})
      assert_rack_call_run_malformed({changed_files:malformed})
    end
  end

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
      'run_cyber_dojo_sh':{
        stdout:'',
        stderr:gcc_assert_stderr,
        status:2,
        colour:'red'
      }
    }
    tuple = rack_call(path_info, args.to_json)
    assert_equal 200, tuple[0]
    assert_equal({ 'Content-Type' => 'application/json' }, tuple[1])

    # Careful here...
    # stderr may or may not have ' (core dumped)' appended.
    # Note that --ulimit core=0 is in place in the runner so
    # no core file is -actually- dumped.
    json = JSON.parse(tuple[2][0])[path_info]
    # C,assert output is compiler-OS dependent. This is gcc,Debian
    assert_equal gcc_assert_stdout, json['stdout']
    assert json['stderr'].start_with?(gcc_assert_stderr), json['stderr']
    assert_equal 2, json['status']
    assert_equal 'red', json['colour']
  end

  private # = = = = = = = = = = = = =

  def assert_rack_call_run_malformed(added)
    expected = { 'exception' => "#{added.keys[0]}:malformed" }
    assert_rack_call_raw('run_cyber_dojo_sh', {
      image_name:image_name,
      kata_id:kata_id,
      avatar_name:'salmon',
      new_files:{},
      deleted_files:{},
      unchanged_files:{},
      changed_files:{},
      max_seconds:10
    }.merge(added).to_json, expected)
  end

  # - - - - - - - - - - - - - - - - -

  def assert_rack_call_raw(path_info, args, expected)
    tuple = rack_call(path_info, args)
    assert_equal 200, tuple[0]
    assert_equal({ 'Content-Type' => 'application/json' }, tuple[1])
    assert_equal [ expected.to_json ], tuple[2]
  end

  def rack_call(path_info, args)
    @external ||= External.new
    runner = Runner.new(@external)
    rack = RackDispatcher.new(runner, RackRequestStub)
    env = { body:args, path_info:path_info }
    rack.call(env)
  end

  # - - - - - - - - - - - - - - - - -

  include ImageNames

  def malformed_kata_ids
    [
      nil,          # not String
      Object.new,   # not String
      [],           # not String
      '',           # not 10 chars
      '123456789',  # not 10 chars
      '123456789AB',# not 10 chars
      '123456789='  # not 10 base58-chars
    ]
  end

  # - - - - - - - - - - - - - - - - -

  def malformed_avatar_names
    [
      nil,          # not String
      Object.new,   # not String
      [],           # not String
      {},           # not String
      '',           # not avatar-name
      'waterbottle' # not avatar-name
    ]
  end

  # - - - - - - - - - - - - - - - - -

  def malformed_files
    [
      nil,           # not Hash
      Object.new,    # not Hash
      [],            # not Hash
      '',            # not Hash
      'waterbottle', # not Hash
      { 'x' => [] }, # value not String
    ]
  end

  # - - - - - - - - - - - - - - - - -

  def malformed_max_seconds
    [
      nil,         # not Integer
      Object.new,  # not Integer
      [],          # not Integer
      {},          # not Integer
      '',          # not Integer
      12.45,       # not Integer
      -1,          # not (1..20)
      0,           # not (1..20)
      21           # not (1..20)
    ]
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

end
