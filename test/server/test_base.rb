require_relative '../id58_test_base'
require_relative 'http_adapter'
require_relative 'services/languages_start_points'
require_relative 'traffic_light_stub'
require_src 'externals'
require_src 'prober'
require_src 'runner'
require 'json'
require 'stringio'

class TestBase < Id58TestBase

  def initialize(arg)
    super(arg)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def externals(options = {})
    @externals ||= Externals.new(options)
  end

  def runner(args, options = {})
    Runner.new(externals(options), args)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_sss(script)
    assert_cyber_dojo_sh(script, traffic_light:TrafficLightStub::red)
  end

  def assert_cyber_dojo_sh(script, options = {})
    options[:changed] = { 'cyber-dojo.sh' => script }
    run_cyber_dojo_sh(options)
    refute_timed_out
    stdout
  end

  def run_cyber_dojo_sh(options = {})
    unchanged_files = starting_files

    created_files = defaulted_arg(options, :created, {})
    created_files.keys.each do |filename|
      info = "#{filename} is not a created_file (it already exists)"
      refute unchanged_files.keys.include?(filename), info
    end

    changed_files = defaulted_arg(options, :changed, {})
    changed_files.keys.each do |filename|
      info = "#{filename} is not a changed_file (it does not already exist)"
      assert unchanged_files.keys.include?(filename), info
      unchanged_files.delete(filename)
    end

    args = {
      'id' => id,
      'files' => [ *unchanged_files, *changed_files, *created_files ].to_h,
      'manifest' => {
        'image_name' => defaulted_arg(options, :image_name, image_name),
        'max_seconds' => defaulted_arg(options, :max_seconds, max_seconds),
        'hidden_filenames' => defaulted_arg(options, :hidden_filenames, [])
      }
    }
    @result = runner(args,options).run_cyber_dojo_sh
    nil
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :result

  def pretty_result(context)
    JSON.pretty_generate(result) + "\nCONTEXT:#{context}:\n"
  end

  def run_result
    result[:run_cyber_dojo_sh]
  end

  def stdout
    run_result[:stdout][:content]
  end

  def stderr
    run_result[:stderr][:content]
  end

  def timed_out?
    run_result[:timed_out]
  end

  def colour
    run_result[:colour]
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

  def log
    run_result[:log]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def clean?(log_ = log)
    log_.empty? || (on_ci? && known_circleci_warning?)
  end

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

  def assert_timed_out
    assert timed_out?, result
  end

  def refute_timed_out
    refute timed_out?, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_created(expected)
    assert_hash_equal(expected, created, :created)
  end

  def assert_deleted(expected)
    assert_equal(expected, deleted, :deleted)
  end

  def assert_changed(expected)
    assert_hash_equal(expected, changed, :changed)
  end

  def assert_hash_equal(expected, actual, context)
    assert_equal expected.keys.sort, actual.keys.sort, pretty_result(context)
    expected.keys.each do |key|
      assert_equal expected[key], actual[key], pretty_result("#{context}-#{key}")
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_name
    manifest['image_name']
  end

  def max_seconds
    manifest['max_seconds'] || 10
  end

  def hidden_filenames
    manifest['hidden_filenames']
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
    manifest['visible_files'].each.with_object({}) do |(filename,file),memo|
      memo[filename] = file['content']
    end
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

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def self.test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
  end

  def self.multi_os_test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
    ubuntu_test(id_suffix, *lines, &block)
  end

  # OS specific tests

  def self.alpine_test(id_suffix, *lines, &block)
    define_test(:Alpine, 'C#, NUnit', id_suffix, *lines, &block)
  end

  def self.ubuntu_test(id_suffix, *lines, &block)
    define_test(:Ubuntu, 'VisualBasic, NUnit', id_suffix, *lines, &block)
  end

  # Language-Test-Framework specific tests

  def self.c_assert_test(id_suffix, *lines, &block)
    define_test(:Debian, 'C (gcc), assert', id_suffix, *lines, &block)
  end

  def self.clang_assert_test(id_suffix, *lines, &block)
    define_test(:Ubuntu, 'C (clang), assert', id_suffix, *lines, &block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def intact(content)
    { content: content, truncated: false }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def stat_cmd
    # Works on Ubuntu and Alpine
    'stat -c "%n %A %u %G %s" *'
    # hiker.h  -rw-r--r--  40045  cyber-dojo 136  2016-06-05
    # |        |           |      |          |    |
    # filename permissions uid    group      size date
    # 0        1           2      3          4    5
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_sha(string)
    assert_equal 40, string.size
    string.each_char do |ch|
      assert '0123456789abcdef'.include?(ch)
    end
  end

end
