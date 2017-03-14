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

  def sss_run(named_args = {})
    # don't name this run() as it clashes with MiniTest
    @sss = runner.run *defaulted_args(named_args)
    [stdout,stderr,status]
  end

  def sss; @sss; end
  def stdout; sss[:stdout]; end
  def stderr; sss[:stderr]; end
  def status; sss[:status]; end

  def assert_stdout(expected); assert_equal expected, stdout, sss; end
  def assert_stderr(expected); assert_equal expected, stderr, sss; end
  def assert_status(expected); assert_equal expected, status, sss; end

  def assert_stdout_include(text); assert stdout.include?(text), sss; end
  def assert_stderr_include(text); assert stderr.include?(text), sss; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh(script, named_args = {})
    named_args[:visible_files] = { 'cyber-dojo.sh' => script }
    assert_run_succeeds(named_args)
  end

  def assert_run_succeeds(named_args)
    stdout,stderr,status = sss_run(named_args)
    assert_equal success, status, [stdout,stderr]
    assert_equal '', stderr, stdout
    stdout
  end

  def assert_run_times_out(named_args)
    stdout,stderr,status = sss_run(named_args)
    assert_stdout ''
    assert_stderr ''
    assert_status timed_out
  end

  def timed_out; 'timed_out'; end
  def success; shell.success; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

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

  def default_image_name; image_from_test_name; end
  def default_kata_id; hex_test_id + '0' * (10-hex_test_id.length); end
  def default_avatar_name; 'salmon'; end
  def default_visible_files; @files ||= read_files; end
  def default_max_seconds; 10; end

  def read_files(language_dir = language_from_test_name)
    dir = "/app/start_files/#{language_dir}"
    json = JSON.parse(IO.read("#{dir}/manifest.json"))
    Hash[json['visible_filenames'].collect { |filename|
      [filename, IO.read("#{dir}/#{filename}")]
    }]
  end

  def image_from_test_name
    "#{cdf}/#{language_from_test_name}"
  end

  def language_from_test_name
    rows = {
      '[C#,NUnit]'      => 'csharp_nunit',
      '[C#,Moq]'        => 'csharp_moq',
      '[Java,Cucumber]' => 'java_cucumber_pico',
      '[gcc,assert]'    => 'gcc_assert',
      '[Alpine]'        => 'gcc_assert',
      '[Ubuntu]'        => 'clangpp_assert'
    }
    row = rows.detect { |key,_| hex_test_name.start_with? key }
    row ? row[1] : 'gcc_assert'
  end

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
