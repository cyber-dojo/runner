require_relative 'test_base'

class ApiRobustnessTest < TestBase

  def self.hex_prefix
    '375'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '2F0',
  'call to non existent method becomes exception' do
    assert_exception('does_not_exist', {}.to_json)
  end

  # - - - - - - - - - - - - - - - - - - -

  multi_os_test '2F1',
  'call to existing method with bad json becomes exception' do
    assert_exception('does_not_exist', '{x}')
  end

  # - - - - - - - - - - - - - - - - - - -

  multi_os_test '2F2',
  'call to existing method with missing argument becomes exception' do
    args = { image_name:image_name, id:id }
    assert_exception('kata_new', args.to_json)
  end

  # - - - - - - - - - - - - - - - - - - -

  multi_os_test '2F3',
  'call to existing method with bad argument type becomes exception' do
    args = {
      image_name:image_name,
      id:id,
      files:2, # <=====
      max_seconds:2
    }
    assert_exception('run_cyber_dojo_sh', args.to_json)
  end

  # - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D21',
  'all api methods raise when image_name is invalid' do
    METHOD_NAMES.each do |method_name|
      MALFORMED_IMAGE_NAMES.each do |image_name|
        error = assert_raises(ServiceError, method_name.to_s) do
          self.send method_name, { image_name:image_name }
        end
        json = JSON.parse(error.message)
        assert_equal 'RunnerStatelessService', json['class']
        assert_equal 'image_name:malformed', json['message']
        assert_equal 'Array', json['backtrace'].class.name
      end
    end
  end

  # - - - - - - - - - - - - - - - - - - -

  multi_os_test '656',
  'all api methods raise when kata_id is invalid' do
    METHOD_NAMES.each do |method_name|
      MALFORMED_IDS.each do |id|
        error = assert_raises(ServiceError, method_name.to_s) do
          self.send method_name, { id:id }
        end
        json = JSON.parse(error.message)
        assert_equal 'RunnerStatelessService', json['class']
        assert_equal 'id:malformed', json['message']
        assert_equal 'Array', json['backtrace'].class.name
      end
    end
  end

  private

  METHOD_NAMES = [ :run_cyber_dojo_sh ]

  MALFORMED_IMAGE_NAMES = [ nil, '_cantStartWithSeparator' ]

  MALFORMED_IDS = [ nil, '675' ]

  include HttpJsonService

  def hostname
    'runner-stateless'
  end

  def port
    4597
  end

  def assert_exception(method_name, jsoned_args)
    json = http(method_name, jsoned_args) { |uri|
      Net::HTTP::Post.new(uri)
    }
    refute_nil json['exception']
  end

end
