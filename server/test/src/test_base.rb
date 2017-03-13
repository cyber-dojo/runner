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
    args = []
    args << defaulted_arg(named_args, :image_name, "#{cdf}/gcc_assert")
    args << defaulted_arg(named_args, :visible_files, files={})
    args << defaulted_arg(named_args, :max_seconds, 10)
    @sss = runner.run(*args)
    [stdout,stderr,status]
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  def sss; @sss; end

  def stdout; sss[:stdout]; end
  def stderr; sss[:stderr]; end
  def status; sss[:status]; end

  def cdf; 'cyberdojofoundation'; end

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

end
