require_relative 'hex_mini_test'
require_relative '../src/external'
require_relative '../src/runner'
require 'stringio'

class TestBase < HexMiniTest

  def external
    @external ||= External.new
  end

  def runner
    Runner.new(external)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def ready?
    runner.ready?
  end

  def sha
    runner.sha
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(named_args = {})

    unchanged_files = @files || starting_files

    created_files = defaulted_arg(named_args, :created, {})
    created_files.keys.each do |filename|
      diagnostic = "#{filename} is not a created_file (it already exists)"
      refute unchanged_files.keys.include?(filename), diagnostic
    end

    deleted_files = defaulted_arg(named_args, :deleted, {})
    deleted_files.keys.each do |filename|
      diagnostic = "#{filename} is not a deleted_file (it does not already exist)"
      assert unchanged_files.keys.include?(filename), diagnostic
      unchanged_files.delete(filename)
    end

    changed_files = defaulted_arg(named_args, :changed, {})
    changed_files.keys.each do |filename|
      diagnostic = "#{filename} is not a changed_file (it does not already exist)"
      assert unchanged_files.keys.include?(filename), diagnostic
      unchanged_files.delete(filename)
    end

    @files = [ *unchanged_files, *changed_files, *created_files ].to_h

    args = []
    args << image_name
    args << id
    args << @files
    args << defaulted_arg(named_args, :max_seconds, 10)
    @result = runner.run_cyber_dojo_sh(*args)

    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :result

  def stdout
    result[__method__]['content']
  end

  def stderr
    result[__method__]['content']
  end

  def colour
    result[__method__]
  end

  def created
    result[__method__]
  end

  def deleted
    result[__method__]
  end

  def changed
    result[__method__]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_stdout(expected)
    assert_equal expected, stdout, result
  end

  def refute_stdout(unexpected)
    refute_equal unexpected, stdout, result
  end

  def assert_stderr(expected)
    assert_equal expected, stderr, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_timed_out
    assert timed_out?, result
  end

  def refute_timed_out
    refute timed_out?, result
  end

  def timed_out?
    colour === 'timed_out'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_colour(expected)
    assert_equal expected, colour, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_created(expected)
    assert_hash_equal(expected, created)
  end

  def assert_deleted(expected)
    assert_equal(expected, deleted.keys)
  end

  def assert_changed(expected)
    assert_hash_equal(expected, changed)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh(script)
    named_args = {
      :changed => { 'cyber-dojo.sh' => intact(script) }
    }
    run_cyber_dojo_sh(named_args)
    refute_timed_out
    stdout.strip
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_name
    manifest['image_name']
  end

  def id
    hex_test_id[0..5]
  end

  def uid
    41966
  end

  def group
    'sandbox'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def starting_files
    Hash[manifest['visible_filenames'].collect { |filename|
      [filename, intact(IO.read("#{starting_files_dir}/#{filename}"))]
    }]
  end

  def manifest
    JSON.parse(IO.read("#{starting_files_dir}/manifest.json"))
  end

  def starting_files_dir
    "/app/test/start_files/#{os}"
  end

  def set_OS(os)
    @os = os
    @files = nil
  end

  def os
    if !@os.nil?
      return @os
    elsif hex_test_name.start_with? '[C,assert]'
      :C_assert
    elsif hex_test_name.start_with? '[clang,assert]'
      :clang_assert
    elsif hex_test_name.start_with? '[Alpine]'
      :Alpine
    elsif hex_test_name.start_with? '[Ubuntu]'
      :Ubuntu
    else # default
      :Alpine
    end
  end

  def self.multi_os_test(hex_suffix, *lines, &block)
    alpine_lines = ['[Alpine]'] + lines
    test(hex_suffix+'0', *alpine_lines, &block)
    ubuntu_lines = ['[Ubuntu]'] + lines
    test(hex_suffix+'1', *ubuntu_lines, &block)
  end

  def all_OSes
    [ :Alpine, :Ubuntu, :Debian ]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def with_captured_log
    @log = ''
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('', 'w')
      yield
      @log = $stdout.string
    ensure
      $stdout = old_stdout
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def intact(content)
    { 'content' => content, 'truncated' => false }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_hash_equal(expected, actual)
    assert_equal expected.keys.sort, actual.keys.sort
    expected.keys.each do |key|
      assert_equal expected[key], actual[key], key
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def stat_cmd
    # Works on Ubuntu and Alpine
    'stat -c "%n %A %u %G %s %y" *'
    # hiker.h  -rw-r--r--  40045  cyber-dojo 136  2016-06-05 07:03:14.539952547
    # |        |           |      |          |    |          |
    # filename permissions uid    group      size date       time
    # 0        1           2      3          4    5          6

    # Stat
    #  %z == time of last status change
    #  %y == time of last data modification <<=====
    #  %x == time of last access
    #  %w == time of file birth
  end

end
