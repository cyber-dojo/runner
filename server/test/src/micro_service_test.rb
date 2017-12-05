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
  %w( invalid json or non-hash json becomes standard-exception ) do
    assert_call_raw('kata_new', 'sdfsdf', { exception:'image_name:invalid' })
    assert_call_raw('kata_new', 'null',   { exception:'image_name:invalid' })
    assert_call_raw('kata_new', '[]',     { exception:'image_name:invalid' })
  end

  # - - - - - - - - - - - - - - - - -

  test 'A53',
  %w( invalid image_name raises ) do
    invalid_image_names.each do |invalid_image_name|
      assert_call_raw('kata_new', {
          image_name:invalid_image_name,
          kata_id:kata_id
        }.to_json, {
          exception:'image_name:invalid'
        })
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '6FD',
  %w( invalid kata_id raises ) do
    invalid_kata_ids.each do |invalid_kata_id|
      assert_call_raw('kata_new', {
          image_name:image_name,
          kata_id:invalid_kata_id
        }.to_json, {
          exception:'kata_id:invalid'
        })
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '685',
  %w( invalid avatar_name raises ) do
    invalid_avatar_names.each do |invalid_avatar_name|
      assert_call_raw('avatar_old', {
          image_name:image_name,
          kata_id:kata_id,
          avatar_name:invalid_avatar_name
        }.to_json, {
          exception:'avatar_name:invalid'
        })
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB1',
  %w( nil nil ) do
    assert_call(nil, nil, { exception:'image_name:invalid' })
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB2', 'image_pulled' do
    assert_call('image_pulled', nil, { exception:'image_name:invalid' })
    assert_call('image_pull'  , nil, { exception:'image_name:invalid' })
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB4', 'kata_new' do
    assert_call('kata_new', {}, { kata_new:nil })
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB5', 'kata_old' do
    assert_call('kata_old', {}, { kata_old:nil })
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB6', 'avatar_new' do
    assert_call('avatar_new', {
        avatar_name:'salmon',
        starting_files:starting_files
      }, {
        avatar_new:nil
      }
    )
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB7', 'avatar_old' do
    assert_call('avatar_old', {
        avatar_name:'salmon'
      }, {
        avatar_old:nil
      }
    )
  end

  # - - - - - - - - - - - - - - - - -

  test 'BB8', 'run_cyber_dojo_sh' do
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
      nil,          # not string
      Object.new,   # not string
      [],           # not string
      '',           # not 10 chars
      '123456789',  # not 10 chars
      '123456789AB',# not 10 chars
      '123456789G'  # not 10 hex-chars
    ]
  end

  # - - - - - - - - - - - - - - - - -

  def invalid_avatar_names
    [
      nil,          # not string
      Object.new,   # not string
      [],           # not string
      {},           # not string
      '',           # not avatar name
      'waterbottle' # not avatar name
    ]
  end

end
