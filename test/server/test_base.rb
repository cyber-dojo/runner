require_relative '../id58_test_base'
require_relative 'http_proxy/languages_start_points'
require_relative 'doubles/stdout_logger_spy'
require_relative 'doubles/process_adapter_stub'
require_relative 'doubles/rack_request_stub'
require_relative 'doubles/bash_sheller_stub'
require_relative 'doubles/traffic_light_stub'
require_relative 'doubles/synchronous_threader'
require_source 'context'
require 'json'

class TestBase < Id58TestBase

  def initialize(arg)
    super(arg)
    context(logger:StdoutLoggerSpy.new)
  end

  def context(options = {})
    @context ||= Context.new(options)
  end

  def runner
    context.runner
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 1. test on one OS or many

  def self.test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
  end

  def self.multi_os_test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
    #debian_test(id_suffix, *lines, &block)
    ubuntu_test(id_suffix, *lines, &block)
  end

  # OS specific tests

  def self.alpine_test(id_suffix, *lines, &block)
    self.csharp_nunit_test(id_suffix, *lines, &block)
  end

  def self.debian_test(id_suffix, *lines, &block)
    self.c_assert_test(id_suffix, *lines, &block)
  end

  def self.ubuntu_test(id_suffix, *lines, &block)
    self.clang_assert_test(id_suffix, *lines, &block)
  end

  # Language-Test-Framework specific tests

  def self.csharp_nunit_test(id_suffix, *lines, &block)
    define_test(:Alpine, 'C#, NUnit', id_suffix, *lines, &block)
  end

  def self.c_assert_test(id_suffix, *lines, &block)
    define_test(:Debian, 'C (gcc), assert', id_suffix, *lines, &block)
  end

  def self.clang_assert_test(id_suffix, *lines, &block)
    define_test(:Ubuntu, 'C (clang), assert', id_suffix, *lines, &block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 2. call helpers

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

    files = [ *unchanged_files, *changed_files, *created_files ].to_h
    manifest = {
      'image_name' => defaulted_arg(options, :image_name, image_name),
      'max_seconds' => defaulted_arg(options, :max_seconds, max_seconds)
    }

    @run_result = runner.run_cyber_dojo_sh(
      id:id,
      files:files,
      manifest:manifest
    )
    nil
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 3. call arguments

  def id
    id58[0..5]
  end

  def starting_files
    manifest['visible_files'].each.with_object({}) do |(filename,file),memo|
      memo[filename] = file['content']
    end
  end

  def image_name
    manifest['image_name']
  end

  def max_seconds
    manifest['max_seconds']
  end

  def manifest
    @manifest ||= languages_start_points.manifest(display_name)
  end

  def languages_start_points
    HttpProxy::LanguagesStartPoints.new
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 4. call results

  def stdout; run_result[:stdout][:content]; end
  def stderr; run_result[:stderr][:content]; end

  def timed_out?; run_result[:timed_out]; end
  def colour;     run_result[:colour]; end

  def created; run_result[:created]; end
  def deleted; run_result[:deleted]; end
  def changed; run_result[:changed]; end

  def pretty_result(tag)
    [ JSON.pretty_generate(run_result),
      "CONTEXT:#{tag}:"
    ].join("\n")
  end

  attr_reader :run_result

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 5. custom asserts

  def assert_sss(script)
    assert_cyber_dojo_sh(script, traffic_light:TrafficLightStub::red)
  end

  def assert_cyber_dojo_sh(script, options = {})
    options[:changed] = { 'cyber-dojo.sh' => script }
    run_cyber_dojo_sh(options)
    refute_timed_out
    stdout
  end

  def assert_timed_out
    assert timed_out?, run_result
  end

  def refute_timed_out
    refute timed_out?, run_result
  end

  def assert_created(expected)
    assert_hash_equal expected, created, :created
  end

  def assert_deleted(expected)
    assert_equal expected, deleted, :deleted
  end

  def assert_changed(expected)
    assert_hash_equal expected, changed, :changed
  end

  def assert_hash_equal(expected, actual, context)
    assert_equal expected.keys.sort, actual.keys.sort, pretty_result(context)
    expected.keys.each do |key|
      assert_equal expected[key], actual[key], pretty_result("#{context}-#{key}")
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 6. misc helpers

  def logged?(message)
    log.include?(message)
  end

  def log
    context.logger.logged
  end

  def uid
    41966
  end

  def group
    'sandbox'
  end

  def intact(content)
    { content:content, truncated:false }
  end

  def stat_cmd
    # Works on Alpine, Debain, Ubuntu
    'stat -c "%n %A %u %G %s" *'
    # hiker.h  -rw-r--r--  40045  cyber-dojo 136
    # |        |           |      |          |
    # filename permissions uid    group      size
    # 0        1           2      3          4
    # %n       %A          %u     %G         %s
  end

  def assert_sha(sha)
    assert sha.is_a?(String), :class
    assert_equal 40, sha.size, :size
    sha.each_char do |ch|
      assert is_lo_hex?(ch), ch
    end
  end

  def is_lo_hex?(ch)
    '0123456789abcdef'.include?(ch)
  end

end
