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

  private

  include HttpJsonService

  def hostname
    'runner-server'
  end

  def port
    4597
  end

  def assert_exception(method_name, jsoned_args)
    json = http(method_name, jsoned_args) { |uri|
      Net::HTTP::Get.new(uri)
    }
    refute_nil json['exception']
  end

end
