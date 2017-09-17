require_relative '../hex_mini_test'
require_relative '../../src/externals'
require_relative '../../src/runner'
require 'json'

class TestBase < HexMiniTest

  include Externals

  def runner
    Runner.new(self, image_name, kata_id)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def set_image_name(image_name)
    @image_name = image_name
  end

  def image_name
    @image_name || "#{cdf}/#{image_from_test_name}"
  end

  def image_from_test_name
    rows = {
      '[Java,Cucumber]' => 'java_cucumber_pico',
      '[gcc,assert]'    => 'gcc_assert',
      '[Alpine]'        => 'gcc_assert',
      '[Ubuntu]'        => 'clangpp_assert'
    }
    row = rows.detect { |key,_| hex_test_name.include? key }
    row ? row[1] : 'gcc_assert'
  end

  def invalid_image_names
    [
      '_',            # cannot start with separator
      'name_',        # cannot end with separator
      'ALPHA/name',   # no uppercase
      'alpha/name_',  # cannot end in separator
      'alpha/_name',  # cannot begin with separator
      'n:tag space',  # tags can't contain a space
      'n:-tag',       # tags can't start with a -
      'n:.tag',       # tags can't start with a .
      ''              # nothing!
    ]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def set_kata_id(kata_id)
    @kata_id = kata_id
  end

  def kata_id
    @kata_id || kata_id_from_test_id
  end

  def kata_id_from_test_id
    hex_test_id + '0' * (10-hex_test_id.length)
  end

  def invalid_kata_ids
    [
      Object.new,   # not string
      [],           # not string
      '',           # not 10 chars
      '123456789',  # not 10 chars
      '123456789AB',# not 10 chars
      '123456789G'  # not 10 hex-chars
    ]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_pulled?
    runner.image_pulled?
  end

  def image_pull
    runner.image_pull
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def sss_run(named_args = {})
    # don't name this run() as it clashes with MiniTest
    @sss = runner.run *defaulted_args(named_args)
    [stdout,stderr,status,colour]
  end

  def sss
    @sss
  end

  def stdout
    sss[:stdout]
  end

  def stderr
    sss[:stderr]
  end

  def status
    sss[:status]
  end

  def colour
    sss[:colour]
  end

  def assert_stdout(expected)
    assert_equal expected, stdout, sss
  end

  def assert_stderr(expected)
    assert_equal expected, stderr, sss
  end

  def assert_status(expected)
    assert_equal expected, status, sss
  end

  def assert_colour(expected)
    assert_equal expected, colour, sss
  end

  def assert_stdout_include(text)
    assert stdout.include?(text), sss
  end

  def assert_stderr_include(text)
    assert stderr.include?(text), sss
  end

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

  def timed_out
    runner.timed_out
  end

  def success
    shell.success
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def defaulted_args(named_args)
    avatar_name   = defaulted_arg(named_args, :avatar_name,   default_avatar_name)
    visible_files = defaulted_arg(named_args, :visible_files, default_visible_files)
    max_seconds   = defaulted_arg(named_args, :max_seconds,   default_max_seconds)
    [avatar_name, visible_files, max_seconds]
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  def default_avatar_name
    'salmon'
  end

  def default_visible_files
    @files ||= read_files
  end

  def default_max_seconds
    10
  end

  def read_files(language_dir = language_dir_from_test_name)
    dir = "/app/test/start_files/#{language_dir}"
    json = JSON.parse(IO.read("#{dir}/manifest.json"))
    Hash[json['visible_filenames'].collect { |filename|
      [filename, IO.read("#{dir}/#{filename}")]
    }]
  end

  def language_dir_from_test_name
    image_from_test_name
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def gcc_assert_files
    @gcc_assert_files ||= read_files('gcc_assert')
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

  def cdf
    'cyberdojofoundation'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def ls_cmd;
    # Works on Ubuntu and Alpine
    'stat -c "%n %A %u %G %s %z" *'
    # hiker.h  -rw-r--r--  40045  cyber-dojo 136  2016-06-05 07:03:14.000000000
    # |        |           |      |          |    |          |
    # filename permissions user   group      size date       time
    # 0        1           2      3          4    5          6
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def ls_parse(ls_stdout)
    Hash[ls_stdout.split("\n").collect { |line|
      attr = line.split
      [filename = attr[0], {
        permissions: attr[1],
               user: attr[2].to_i,
              group: attr[3],
               size: attr[4].to_i,
         time_stamp: attr[6],
      }]
    }]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_equal_atts(filename, permissions, user, group, size, ls_files)
    atts = ls_files[filename]
    refute_nil atts, filename
    assert_equal user,  atts[:user ], { filename => atts }
    assert_equal group, atts[:group], { filename => atts }
    assert_equal size,  atts[:size ], { filename => atts }
    assert_equal permissions, atts[:permissions], { filename => atts }
  end

end
