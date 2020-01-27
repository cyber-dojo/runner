require_relative 'hex_mini_test'
require_relative 'http_adapter'
require_relative 'services/languages_start_points'
require_relative '../src/externals'
require_relative '../src/runner'
require 'stringio'

class TestBase < HexMiniTest

  def initialize(arg)
    super(arg)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def externals
    @externals ||= Externals.new
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def runner
    @runner ||= Runner.new(externals)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def shell
    externals.shell
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def ready?
    runner.ready?['ready?']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def sha
    runner.sha['sha']
  end

  def assert_sha(string)
    assert_equal 40, string.size
    string.each_char do |ch|
      assert '0123456789abcdef'.include?(ch)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(named_args = {})
    unchanged_files = starting_files

    created_files = defaulted_arg(named_args, :created, {})
    created_files.keys.each do |filename|
      info = "#{filename} is not a created_file (it already exists)"
      refute unchanged_files.keys.include?(filename), info
    end

    changed_files = defaulted_arg(named_args, :changed, {})
    changed_files.keys.each do |filename|
      info = "#{filename} is not a changed_file (it does not already exist)"
      assert unchanged_files.keys.include?(filename), info
      unchanged_files.delete(filename)
    end

    args = []
    args << defaulted_arg(named_args, :image_name, image_name)
    args << id
    args << [ *unchanged_files, *changed_files, *created_files ].to_h
    args << defaulted_arg(named_args, :max_seconds, 10)
    @result = runner.run_cyber_dojo_sh(*args)
    nil
  end

  attr_reader :result

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def stdout
    result['run_cyber_dojo_sh'][:stdout]['content']
  end

  def stderr
    result['run_cyber_dojo_sh'][:stderr]['content']
  end

  def timed_out?
    result['run_cyber_dojo_sh'][:timed_out]
  end

  def created
    result['run_cyber_dojo_sh'][:created]
  end

  def deleted
    result['run_cyber_dojo_sh'][:deleted]
  end

  def changed
    result['run_cyber_dojo_sh'][:changed]
  end

  def colour
    result['colour']
  end

  def diagnostic
    result['diagnostic']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_timed_out
    assert timed_out?, result
  end

  def refute_timed_out
    refute timed_out?, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_created(expected)
    assert_hash_equal(expected, created)
  end

  def assert_deleted(expected)
    assert_equal(expected, deleted)
  end

  def assert_changed(expected)
    assert_hash_equal(expected, changed)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh(script)
    named_args = {
      :changed => { 'cyber-dojo.sh' => script }
    }
    run_cyber_dojo_sh(named_args)
    refute_timed_out
    stdout
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
    manifest['visible_files'].map do |filename,file|
      [ filename, file['content'] ]
    end.to_h
  end

  def manifest
    @manifest ||= languages_start_points.manifest(display_name)
  end

  def languages_start_points
    LanguagesStartPoints.new(http)
  end

  def http
    HttpAdapter.new
  end

  def display_name
    case os
    when :C_assert     then 'C (gcc), assert'
    when :clang_assert then 'C (clang), assert'
    when :Alpine       then 'C#, NUnit'
    when :Ubuntu       then 'Perl, Test::Simple'
    when :Debian       then 'Python, py.test'
    else                    'C#, NUnit'
    end
  end

  def os
    if hex_test_name.start_with?('[C,assert]')
      :C_assert
    elsif hex_test_name.start_with?('[clang,assert]')
      :clang_assert
    elsif hex_test_name.start_with?('[Alpine]')
      :Alpine
    elsif hex_test_name.start_with?('[Ubuntu]')
      :Ubuntu
    elsif hex_test_name.start_with?('[Debian]')
      :Debian
    else # default
      :Alpine
    end
  end

  def self.multi_os_test(hex_suffix, *lines, &block)
    alpine_lines = ['[Alpine]'] + lines
    test(hex_suffix+'0', *alpine_lines, &block)
    ubuntu_lines = ['[Ubuntu]'] + lines
    test(hex_suffix+'1', *ubuntu_lines, &block)
    #debian_lines = ['[Debian]'] + lines
    #test(hex_suffix+'2', *debian_lines, &block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def with_captured_log
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('', 'w')
      yield
      $stdout.string
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
