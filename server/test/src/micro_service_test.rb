require_relative 'test_base'
require_relative '../../src/micro_service'
require_relative 'logger_spy'

class MicroServiceTest < TestBase

  def self.hex_prefix
    'D06F7'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'BB1',
  %w( nil nil ) do
    assert_call(nil, nil, {
      "exception":"image_name:invalid"
      }
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'BB2', 'image_pulled' do
    assert_call('image_pulled', nil, { "exception":"image_name:invalid" })
    assert_call('image_pull'  , nil, { "exception":"image_name:invalid" })
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'BB4', 'kata_new' do
    assert_call('kata_new', {
        image_name:image_name,
        kata_id:kata_id
      }.to_json, {
        'kata_new':nil
      }
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'BB5', 'kata_old' do
    assert_call('kata_old', {
        image_name:image_name,
        kata_id:kata_id
      }.to_json, {
        'kata_old':nil
      }
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'BB6', 'avatar_new' do
    assert_call('avatar_new', {
        image_name:image_name,
        kata_id:kata_id,
        avatar_name:salmon,
        starting_files:starting_files
      }.to_json, {
        'avatar_new':nil
      }
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'BB7', 'avatar_old' do
    assert_call('avatar_old', {
        image_name:image_name,
        kata_id:kata_id,
        avatar_name:salmon
      }.to_json, {
        'avatar_old':nil
      }
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'BB8', 'run_cyber_dojo_sh' do
    assert_call('run_cyber_dojo_sh', {
        image_name:image_name,
        kata_id:kata_id,
        avatar_name:salmon,
        new_files:starting_files,
        deleted_files:{},
        unchanged_files:{},
        changed_files:{},
        max_seconds:10
      }.to_json, {
        'run_cyber_dojo_sh':{
          stdout:'',
          stderr:gcc_assert_stderr,
          status:2,
          timed_out:false,
          rag:gcc_assert_rag_lambda,
          colour:'red'
        }
      }
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'BB9', 'run' do
    assert_call('run', {
        image_name:image_name,
        kata_id:kata_id,
        avatar_name:salmon,
        visible_files:starting_files,
        max_seconds:10
      }.to_json, {
        'run':{
          stdout:'',
          stderr:gcc_assert_stderr,
          status:2,
          colour:'red'
        }
      }
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def gcc_assert_rag_lambda
    "\n"+<<~RUBY
    lambda { |stdout, stderr, status|
      output = stdout + stderr
      return :red   if /(.*)Assertion(.*)failed./.match(output)
      return :green if /(All|\\d+) tests passed/.match(output)
      return :amber
    }
    RUBY
  end

  def gcc_assert_stderr
    "Assertion failed: answer() == 42 (hiker.tests.c: life_the_universe_and_everything: 7)\n" +
    "make: *** [makefile:13: test.output] Aborted\n"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_call(path_info, body, expected)
    ms = MicroService.new
    ms.log = LoggerSpy.new(nil)
    tri = ms.call(nil, RequestStub.new(body, path_info))
    assert_equal 200, tri[0]
    assert_equal({ 'Content-Type' => 'application/json' }, tri[1])
    assert_equal [ expected.to_json ], tri[2]
    #TODO: assert on content of ms.log
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  class RequestStub
    def initialize(body, path_info)
      @body = body
      @path_info = path_info
    end
    def body
      RequestBodyStub.new(@body)
    end
    def path_info
      "/#{@path_info}"
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  class RequestBodyStub
    def initialize(body)
      @body = body
    end
    def read
      @body
    end
  end

end
