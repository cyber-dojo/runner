require_relative '../hex_mini_test'
require_relative '../../src/runner_service'

class TestBase < HexMiniTest

  def runner
    RunnerService.new
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def image_pulled?(named_args={})
    image_name = defaulted_arg(named_args, :image_name, default_image_name)
    kata_id    = defaulted_arg(named_args, :kata_id,    default_kata_id)
    runner.image_pulled? image_name, kata_id
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def image_pull(named_args={})
    image_name = defaulted_arg(named_args, :image_name, default_image_name)
    kata_id    = defaulted_arg(named_args, :kata_id,    default_kata_id)
    runner.image_pull image_name, kata_id
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def cdf
    'cyberdojofoundation'
  end

  def default_image_name
    "#{cdf}/gcc_assert"
  end

  def default_kata_id
    hex_test_id + '0' * (10-hex_test_id.length)
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  VALID_IMAGE_NAME    = 'cyberdojofoundation/gcc_assert'
  VALID_KATA_ID       = '41135B4F2B'
  VALID_AVATAR_NAME   = 'salmon'

  INVALID_IMAGE_NAME  = '_cantStartWithSeparator'
  INVALID_KATA_ID     = '675'
  INVALID_AVATAR_NAME = 'sunglasses'

  private

  attr_reader :quad

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

end
