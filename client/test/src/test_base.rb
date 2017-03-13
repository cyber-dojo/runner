require_relative '../hex_mini_test'
require_relative '../../src/runner_service'

class TestBase < HexMiniTest

  def runner
    RunnerService.new
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def image_pulled?(image_name)
    runner.image_pulled? image_name
  end

  def image_pull(image_name)
    runner.image_pull image_name
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

=begin
  def sss_run(named_args = {})
    # don't call this run() as it clashes with MiniTest
    @sss = runner.run *defaulted_args(named_args)
  end

  def sss
    @sss
  end

  def status; sss['status']; end
  def stdout; sss['stdout']; end
  def stderr; sss['stderr']; end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def defaulted_args(named_args)
    args = []
    args << defaulted_arg(named_args, :image_name, default_image_name)
    args << defaulted_arg(named_args, :visible_files, files)
    args << defaulted_arg(named_args, :max_seconds, 10)
    args
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  def default_image_name
    'cyberdojofoundation/gcc_assert'
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def files
    @files ||= read_files
  end

  def read_files
    filenames =%w( hiker.c hiker.h hiker.tests.c cyber-dojo.sh makefile )
    Hash[filenames.collect { |filename|
      [filename, IO.read("/app/start_files/gcc_assert/#{filename}")]
    }]
  end

  def file_sub(name, from, to)
    files[name] = files[name].sub(from, to)
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def assert_success; assert_equal success, status, sss.to_s; end
  def refute_success; refute_equal success, status, sss.to_s; end

  def assert_timed_out; assert_equal timed_out, status, sss.to_s; end

  def assert_stdout(expected); assert_equal expected, stdout, sss.to_s; end
  def assert_stderr(expected); assert_equal expected, stderr, sss.to_s; end
  def assert_status(expected); assert_equal expected, status, sss.to_s; end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def success; 0; end
  def timed_out; 'timed_out'; end
=end

end
