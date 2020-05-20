require_relative '../id58_test_base'
require_relative 'external_bash_stub'
require_relative 'http_adapter'
require_relative 'services/languages_start_points'
require_src 'externals'
require_src 'prober'
require_src 'runner'
require 'stringio'

$externals = Externals.new

class TestBase < Id58TestBase

  def initialize(arg)
    super(arg)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def externals
    $externals
  end

  def stub_bash(stub = ExternalBashStub.new)
    externals.instance_exec { @bash = stub }
  end

  def prober(args)
    Prober.new(externals, args)
  end

  def runner(args)
    Runner.new(externals, args)
  end

  def alive?
    prober({}).alive?['alive?']
  end

  def ready?
    prober({}).ready?['ready?']
  end

  def sha
    prober({}).sha['sha']
  end

  def assert_sha(string)
    assert_equal 40, string.size
    string.each_char do |ch|
      assert '0123456789abcdef'.include?(ch)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh(script)
    named_args = {
      :changed => { 'cyber-dojo.sh' => script }
    }
    run_cyber_dojo_sh(named_args)
    refute timed_out?, result
    stdout
  end

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

    args = {
      'id' => id,
      'files' => [ *unchanged_files, *changed_files, *created_files ].to_h,
      'manifest' => {
        'image_name' => defaulted_arg(named_args, :image_name, image_name),
        'max_seconds' => defaulted_arg(named_args, :max_seconds, 10)
      }
    }
    @result = runner(args).run_cyber_dojo_sh
    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :result

  def pretty_result(context)
    JSON.pretty_generate(result) + "\nCONTEXT:#{context}:\n"
  end

  def run_result
    result['run_cyber_dojo_sh']
  end

  def stdout
    run_result[:stdout]['content']
  end

  def stderr
    run_result[:stderr]['content']
  end

  def status
    run_result[:status]
  end

  def timed_out?
    run_result[:timed_out]
  end

  def created
    run_result[:created]
  end

  def deleted
    run_result[:deleted]
  end

  def changed
    run_result[:changed]
  end

  def colour
    run_result[:colour]
  end

  def log
    run_result[:log]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def log_empty?
    log.empty? || (on_ci? && known_circleci_warning?)
  end

  def on_ci?
    ENV['CIRCLECI'] === 'true'
  end

  def known_circleci_warning?
     log === KNOWN_CIRCLE_CI_WARNING
  end

  KNOWN_CIRCLE_CI_WARNING =
    "WARNING: Your kernel does not support swap limit capabilities or the cgroup is not mounted. " +
    "Memory limited without swap.\n"

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

  def assert_hash_equal(expected, actual)
    assert_equal expected.keys.sort, actual.keys.sort
    expected.keys.each do |key|
      assert_equal expected[key], actual[key], key
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_name
    manifest['image_name']
  end

  def id
    id58[0..5]
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

  def self.test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
  end

  def self.alpine_test(id_suffix, *lines, &block)
    define_test(:Alpine, 'C#, NUnit', id_suffix, *lines, &block)
  end

  def self.ubuntu_test(id_suffix, *lines, &block)
    define_test(:Ubuntu, 'VisualBasic, NUnit', id_suffix, *lines, &block)
  end

  def self.debian_test(id_suffix, *lines, &block)
    define_test(:Debian, 'Python, pytest', id_suffix, *lines, &block)
  end

  def self.multi_os_test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
    debian_test(id_suffix, *lines, &block)
    ubuntu_test(id_suffix, *lines, &block)
  end

  def self.c_assert_test(id_suffix, *lines, &block)
    define_test(:Debian, 'C (gcc), assert', id_suffix, *lines, &block)
  end

  def self.clang_assert_test(id_suffix, *lines, &block)
    define_test(:Ubuntu, 'C (clang), assert', id_suffix, *lines, &block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def with_captured_log
    begin
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = StringIO.new('', 'w')
      $stderr = StringIO.new('', 'w')
      yield
      [ $stdout.string, $stderr.string ]
    ensure
      $stderr = old_stderr
      $stdout = old_stdout
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def intact(content)
    { 'content' => content, 'truncated' => false }
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
