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

  def image_pulled?
    runner.image_pulled?
  end

  def image_pull
    runner.image_pull
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def kata_new
    runner.kata_new
  end

  def kata_old
    runner.kata_old
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def avatar_new(name = salmon)
    runner.avatar_new(@avatar_name = name, @all_files = starting_files)
  end

  def avatar_old(name = avatar_name)
    runner.avatar_old(name)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(named_args = {})

    unchanged_files = @all_files

    changed_files = defaulted_arg(named_args, :changed_files, {})
    changed_files.keys.each do |filename|
      diagnostic = "#{filename} is not a changed_file (it does not already exist)"
      assert unchanged_files.keys.include?(filename), diagnostic
      unchanged_files.delete(filename)
    end
    new_files = defaulted_arg(named_args, :new_files, {})
    new_files.keys.each do |filename|
      diagnostic = "#{filename} is not a new_file (it already exists)"
      refute unchanged_files.keys.include?(filename), diagnostic
    end

    args = []
    args << avatar_name
    args << defaulted_arg(named_args, :deleted_filenames, [])
    args << unchanged_files
    args << changed_files
    args << new_files
    args << defaulted_arg(named_args, :max_seconds, 10)

    @quad = runner.run_cyber_dojo_sh(*args)

    @all_files = [ *unchanged_files, *changed_files, *new_files ].to_h
    nil
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  def salmon
    'salmon'
  end

  def lion
    'lion'
  end

  def squid
    'squid'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def stdout
    quad[:stdout]
  end

  def stderr
    quad[:stderr]
  end

  def status
    quad[:status]
  end

  def colour
    quad[:colour]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_status(expected)
    assert_equal expected, status, quad
  end

  def assert_colour(expected)
    assert_equal expected, colour, quad
  end

  def assert_stdout(expected)
    assert_equal expected, stdout, quad
  end

  def assert_stdout_include(text)
    assert stdout.include?(text), quad
  end


  def assert_stderr(expected)
    assert_equal expected, stderr, quad
  end

  def assert_stderr_include(text)
    assert stderr.include?(text), quad
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh(script, named_args = {})
    named_args[:changed_files] = { 'cyber-dojo.sh' => script }
    assert_run_succeeds(named_args)
  end

  def assert_run_succeeds(named_args)
    run_cyber_dojo_sh(named_args)
    refute_equal timed_out, colour, quad
    assert_stderr ''
    stdout
  end

  def assert_run_times_out(named_args)
    run_cyber_dojo_sh(named_args)
    assert_colour timed_out
    assert_status 137
    assert_stdout ''
    assert_stderr ''
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def set_image_name(image_name)
    @image_name = image_name
  end

  def image_name
    @image_name
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def kata_id
    hex_test_id + '0' * (10-hex_test_id.length)
  end

  def avatar_name
    @avatar_name
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def timed_out
    runner.timed_out
  end

  def home_dir
    runner.home_dir(avatar_name)
  end

  def sandbox_dir
    runner.sandbox_dir(avatar_name)
  end

  def group
    runner.group
  end

  def gid
    runner.gid
  end

  def user_id
    runner.user_id(avatar_name)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def starting_files
    fail 'image_name.nil? so cannot set language_dir' if image_name.nil?
    language_dir = image_name.split('/')[1]
    dir = "/app/test/start_files/#{language_dir}"
    json = JSON.parse(IO.read("#{dir}/manifest.json"))
    Hash[json['visible_filenames'].collect { |filename|
      [filename, IO.read("#{dir}/#{filename}")]
    }]
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

  def ls_cmd;
    # Works on Ubuntu and Alpine
    'stat -c "%n %A %u %G %s %z" *'
    # hiker.h  -rw-r--r--  40045  cyber-dojo 136  2016-06-05 07:03:14.539952547
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

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def in_kata_as(name)
    in_kata {
      as(name) {
        yield
      }
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def in_kata
    set_image_name image_for_test
    kata_new
    yield
  ensure
    kata_old
  end

  def image_for_test
    rows = {
      '[gcc,assert]'    => 'gcc_assert',
      '[Java,Cucumber]' => 'java_cucumber_pico',
      '[Alpine]'        => 'gcc_assert',
      '[Ubuntu]'        => 'clangpp_assert'
    }
    row = rows.detect { |key,_| hex_test_name.start_with? key }
    row ||= [ nil, 'gcc_assert' ] # default
    cdf + '/' + row[1]
  end

  def cdf
    'cyberdojofoundation'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def as(name)
    avatar_new(name)
    yield
  ensure
    avatar_old(name)
  end

  private

  def quad
    @quad
  end

end
