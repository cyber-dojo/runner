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

  def kata_new(named_args={})
    image_name = defaulted_arg(named_args, :image_name, default_image_name)
    kata_id    = defaulted_arg(named_args, :kata_id,    default_kata_id)
    runner.kata_new image_name, kata_id
  end

  def kata_old(named_args={})
    image_name = defaulted_arg(named_args, :image_name, default_image_name)
    kata_id    = defaulted_arg(named_args, :kata_id,    default_kata_id)
    runner.kata_old image_name, kata_id
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def avatar_new(named_args={})
    image_name = defaulted_arg(named_args, :image_name, default_image_name)
    kata_id    = defaulted_arg(named_args, :kata_id,    default_kata_id)
    avatar_name = defaulted_arg(named_args, :avatar_name, default_avatar_name)
    starting_files = defaulted_arg(named_args, :visible_files, default_visible_files)
    runner.avatar_new image_name, kata_id, avatar_name, starting_files
  end

  def avatar_old(named_args={})
    image_name = defaulted_arg(named_args, :image_name, default_image_name)
    kata_id    = defaulted_arg(named_args, :kata_id,    default_kata_id)
    avatar_name = defaulted_arg(named_args, :avatar_name, default_avatar_name)
    runner.avatar_old image_name, kata_id, avatar_name
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def run4(named_args = {})
    # don't call this run() as it clashes with MiniTest
    @quad = runner.run *defaulted_args(named_args)
    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def stdout
    quad['stdout']
  end

  def stderr
    quad['stderr']
  end

  def status
    quad['status']
  end

  def colour
    quad['colour']
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def assert_colour(expected)
    assert_equal expected, colour, quad
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

  def default_avatar_name
    'salmon'
  end

  def default_visible_files;
    @files ||= read_files
  end

  def default_max_seconds
    10
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def timed_out
    'timed_out'
  end

  VALID_IMAGE_NAME    = 'cyberdojofoundation/gcc_assert'
  VALID_KATA_ID       = '41135B4F2B'
  VALID_AVATAR_NAME   = 'salmon'

  INVALID_IMAGE_NAME  = '_cantStartWithSeparator'
  INVALID_KATA_ID     = '675'
  INVALID_AVATAR_NAME = 'sunglasses'

  private

  attr_reader :quad

  def defaulted_args(named_args)
    image_name    = defaulted_arg(named_args, :image_name,    default_image_name)
    kata_id       = defaulted_arg(named_args, :kata_id,       default_kata_id)
    avatar_name   = defaulted_arg(named_args, :avatar_name,   default_avatar_name)
    visible_files = defaulted_arg(named_args, :visible_files, default_visible_files)
    max_seconds   = defaulted_arg(named_args, :max_seconds,   default_max_seconds)
    [image_name, kata_id, avatar_name, visible_files, max_seconds]
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  def read_files
    filenames =%w( hiker.c hiker.h hiker.tests.c cyber-dojo.sh makefile )
    Hash[filenames.collect { |filename|
      [filename, IO.read("/app/test/start_files/gcc_assert/#{filename}")]
    }]
  end

end
