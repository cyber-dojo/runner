require_relative '../../src/micro_service'
require_relative 'image_names'
require_relative 'request_stub'
require_relative 'test_base'

class MicroServiceTest < TestBase

  def self.hex_prefix
    'D06F7'
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB0',
  %w( invalid json in http payload becomes exception ) do
    assert_call_raw('kata_new', 'sdfsdf', { exception:'json:invalid' })
    assert_call_raw('kata_new', 'nil',    { exception:'json:invalid' })

  end

  # - - - - - - - - - - - - - - - - -

  test 'BB1',
  %w( non-hash in http payload becomes exception ) do
    assert_call_raw('kata_new', 'null',   { exception:'json:!Hash' })
    assert_call_raw('kata_new', '[]',     { exception:'json:!Hash' })
    assert_call(nil           , nil,      { exception:'json:!Hash' })
    assert_call('image_pulled', nil,      { exception:'json:!Hash' })
    assert_call('image_pull'  , nil,      { exception:'json:!Hash' })

  end

  # - - - - - - - - - - - - - - - - -

  test 'BB2',
  %w( invalid image_name becomes exception ) do
    invalid_image_names.each do |invalid|
      assert_call_raw('kata_new', {
          image_name:invalid,
          kata_id:kata_id
        }.to_json, {
          exception:'image_name:invalid'
        }
      )
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB3',
  %w( invalid kata_id becomes exception ) do
    invalid_kata_ids.each do |invalid|
      assert_call_raw('kata_new', {
          image_name:image_name,
          kata_id:invalid
        }.to_json, {
          exception:'kata_id:invalid'
        }
      )
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB4',
  %w( invalid starting_files becomes exception ) do
    invalid_files.each do |invalid|
      assert_call_raw('avatar_new', {
          image_name:image_name,
          kata_id:kata_id,
          avatar_name:'salmon',
          starting_files:invalid
        }.to_json, {
          exception:'starting_files:invalid'
        }
      )
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB5',
  %w( invalid avatar_name becomes exception ) do
    invalid_avatar_names.each do |invalid|
      assert_call_raw('avatar_old', {
          image_name:image_name,
          kata_id:kata_id,
          avatar_name:invalid
        }.to_json, {
          exception:'avatar_name:invalid'
        }
      )
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB7',
  %w( invalid max_seconds becomes exception ) do
    invalid_max_seconds.each do |invalid|
      assert_call_run_invalid({max_seconds:invalid})
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB8',
  %w( invalid files becomes exception ) do
    invalid_files.each do |invalid|
      assert_call_run_invalid({new_files:invalid})
      assert_call_run_invalid({deleted_files:invalid})
      assert_call_run_invalid({unchanged_files:invalid})
      assert_call_run_invalid({changed_files:invalid})
    end
  end

  # - - - - - - - - - - - - - - - - -

  def assert_call_run_invalid(added)
    expected = { 'exception' => "#{added.keys[0]}:invalid" }
    assert_call_raw('run_cyber_dojo_sh', {
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
  # - - - - - - - - - - - - - - - - -

  test 'AB5', 'kata_new' do
    assert_call('kata_new', {}, { kata_new:nil })
  end

  # - - - - - - - - - - - - - - - - -

  test 'AB6', 'kata_old' do
    assert_call('kata_old', {}, { kata_old:nil })
  end

  # - - - - - - - - - - - - - - - - -

  test 'AB7', 'avatar_new' do
    assert_call('avatar_new', {
        avatar_name:'salmon',
        starting_files:starting_files
      }, {
        avatar_new:nil
      }
    )
  end

  # - - - - - - - - - - - - - - - - -

  test 'AB8', 'avatar_old' do
    assert_call('avatar_old', {
        avatar_name:'salmon'
      }, {
        avatar_old:nil
      }
    )
  end

  # - - - - - - - - - - - - - - - - -

  test 'AB9', 'run_cyber_dojo_sh' do
    assert_call('run_cyber_dojo_sh', {
        avatar_name:'salmon',
        new_files:starting_files,
        deleted_files:{},
        unchanged_files:{},
        changed_files:{},
        max_seconds:10
      }, {
        'run_cyber_dojo_sh':{
          stdout:'',
          stderr:gcc_assert_stderr,
          status:2,
          colour:'red'
        }
      }
    )
  end

  private # = = = = = = = = = = = = =

  def gcc_assert_stderr
    "Assertion failed: answer() == 42 (hiker.tests.c: life_the_universe_and_everything: 7)\n" +
    "make: *** [makefile:13: test.output] Aborted\n"
  end

  # - - - - - - - - - - - - - - - - -

  def assert_call(path_info, args, expected)
    unless args.nil?
      args['image_name'] ||= image_name
      args['kata_id'] ||= kata_id
    end
    assert_call_raw(path_info, args.to_json, expected)
  end

  def assert_call_raw(path_info, args, expected)
    tuple = MicroService.new.call(nil, RequestStub.new(args, path_info))
    assert_equal 200, tuple[0]
    assert_equal({ 'Content-Type' => 'application/json' }, tuple[1])
    assert_equal [ expected.to_json ], tuple[2]
  end

  # - - - - - - - - - - - - - - - - -

  include ImageNames

  def invalid_kata_ids
    [
      nil,          # not String
      Object.new,   # not String
      [],           # not String
      '',           # not 10 chars
      '123456789',  # not 10 chars
      '123456789AB',# not 10 chars
      '123456789G'  # not 10 hex-chars
    ]
  end

  # - - - - - - - - - - - - - - - - -

  def invalid_avatar_names
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

  def invalid_files
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

  def invalid_max_seconds
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

end
