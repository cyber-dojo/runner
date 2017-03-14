require_relative '../hex_mini_test'
require_relative '../../src/externals'
require_relative '../../src/runner'
require 'json'

class TestBase < HexMiniTest

  include Externals

  def runner
    @runner ||= Runner.new(self)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_pulled?(image_name)
    runner.image_pulled?(image_name)
  end

  def image_pull(image_name)
    runner.image_pull(image_name)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def sss_run(named_args = {})
    # don't name this run() as it clashes with MiniTest
    @sss = runner.run *defaulted_args(named_args)
    [stdout,stderr,status]
  end

  def defaulted_args(named_args)
    args = []
    args << defaulted_arg(named_args, :image_name,    default_image_name)
    args << defaulted_arg(named_args, :kata_id,       default_kata_id)
    args << defaulted_arg(named_args, :avatar_name,   default_avatar_name)
    args << defaulted_arg(named_args, :visible_files, default_visible_files)
    args << defaulted_arg(named_args, :max_seconds,   default_max_seconds)
    args
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  def default_image_name; "#{cdf}/gcc_assert"; end
  def default_kata_id; hex_test_id + '0' * (10-hex_test_id.length); end
  def default_avatar_name; 'salmon'; end
  def default_visible_files; @files ||= {}; end #read_files; end
  def default_max_seconds; 10; end

  def sss; @sss; end

  def stdout; sss[:stdout]; end
  def stderr; sss[:stderr]; end
  def status; sss[:status]; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def with_captured_stdout
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('','w')
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def invalid_image_names
    [
      '',             # nothing!
      '_',            # cannot start with separator
      'name_',        # cannot end with separator
      'ALPHA/name',   # no uppercase
      'alpha/name_',  # cannot end in separator
      'alpha/_name',  # cannot begin with separator
    ]
  end

  def cdf; 'cyberdojofoundation'; end

end
