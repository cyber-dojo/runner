require_relative '../hex_mini_test'
require_relative '../../src/runner_service'

class TestBase < HexMiniTest

  def runner
    RunnerService.new
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def image_exists?(image_name)
    runner.image_exists? image_name
  end

  def image_pulled?(image_name)
    runner.image_pulled? image_name
  end

  def image_pull(image_name)
    runner.image_pull image_name
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def sss_run(named_args = {})
    # don't call this run() as it clashes with MiniTest
    @sss ||= runner.run *defaulted_args(named_args)
  end

  def sss
    @sss
  end

  def status; sss['status']; end
  def stdout; sss['stdout']; end
  def stderr; sss['stderr']; end

  # - - - - - - - - - - - - - - - - - - - - - - -

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

  def default_image_name; "#{cdf}/gcc_assert"; end
  def default_kata_id; hex_test_id + '0' * (10-hex_test_id.length); end
  def default_avatar_name; 'salmon'; end
  def default_visible_files; @files ||= read_files; end
  def default_max_seconds; 10; end

  def cdf; 'cyberdojofoundation'; end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def read_files
    filenames =%w( hiker.c hiker.h hiker.tests.c cyber-dojo.sh makefile )
    Hash[filenames.collect { |filename|
      [filename, IO.read("/app/start_files/gcc_assert/#{filename}")]
    }]
  end

=begin
  def file_sub(name, from, to)
    files[name] = files[name].sub(from, to)
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def assert_success; assert_equal success, status, sss.to_s; end
  def refute_success; refute_equal success, status, sss.to_s; end

  def assert_timed_out; assert_equal timed_out, status, sss.to_s; end
=end

  def assert_stdout(expected); assert_equal expected, stdout, sss.to_s; end
  def assert_stderr(expected); assert_equal expected, stderr, sss.to_s; end
  def assert_status(expected); assert_equal expected, status, sss.to_s; end

  # - - - - - - - - - - - - - - - - - - - - - - -

=begin
  def success; 0; end
  def timed_out; 'timed_out'; end
=end

  VALID_IMAGE_NAME    = 'cyberdojofoundation/gcc_assert'
  VALID_KATA_ID       = '41135B4F2B'
  VALID_AVATAR_NAME   = 'salmon'

  VALID_NON_EXISTENT_IMAGE_NAME = 'non_existent_box'
  INVALID_IMAGE_NAME            = '_cantStartWithSeparator'
  INVALID_KATA_ID     = '675'
  INVALID_AVATAR_NAME = 'sunglasses'

end
