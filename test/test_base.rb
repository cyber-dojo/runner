require_relative 'data/display_names'
require_relative 'doubles/all'
require_relative 'id58_test_base'
require_code 'context'
require 'json'

class TestBase < Id58TestBase
  def set_context(options = {})
    @context = Context.new(options)
  end

  attr_reader :context, :run_result

  def node
    context.node
  end

  def prober
    context.prober
  end

  def puller
    context.puller
  end

  def runner
    context.runner
  end

  def sheller
    context.sheller
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 1. test on one OS or many

  def self.test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
  end

  def self.multi_os_test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
    debian_test(id_suffix, *lines, &block)
    ubuntu_test(id_suffix, *lines, &block)
  end

  # OS specific tests

  def self.alpine_test(id_suffix, *lines, &block)
    c_assert_test(id_suffix, *lines, &block)
  end

  def self.debian_test(id_suffix, *lines, &block)
    perl_testsimple_test(id_suffix, *lines, &block)
  end

  def self.ubuntu_test(id_suffix, *lines, &block)
    clang_assert_test(id_suffix, *lines, &block)
  end

  # Language-Test-Framework specific tests

  def self.c_assert_test(id_suffix, *lines, &block)
    define_test(:Alpine, DisplayNames::ALPINE, id_suffix, *lines, &block)
  end

  def self.perl_testsimple_test(id_suffix, *lines, &block)
    define_test(:Debian, DisplayNames::DEBIAN, id_suffix, *lines, &block)
  end

  def self.clang_assert_test(id_suffix, *lines, &block)
    define_test(:Ubuntu, DisplayNames::UBUNTU, id_suffix, *lines, &block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 2. call helper

  def run_cyber_dojo_sh(options = {})
    unchanged_files = starting_files

    created_files = defaulted_arg(options, :created, {})
    created_files.each_key do |filename|
      info = "#{filename} is not a created_file (it already exists)"
      refute unchanged_files.keys.include?(filename), info
    end

    changed_files = defaulted_arg(options, :changed, {})
    changed_files.each_key do |filename|
      info = "#{filename} is not a changed_file (it does not already exist)"
      assert unchanged_files.keys.include?(filename), info
      unchanged_files.delete(filename)
    end

    files = [*unchanged_files, *changed_files, *created_files].to_h
    manifest = {
      'image_name' => defaulted_arg(options, :image_name, image_name),
      'max_seconds' => defaulted_arg(options, :max_seconds, max_seconds)
    }

    @run_result = runner.run_cyber_dojo_sh(
      id: id,
      files: files,
      manifest: manifest
    )
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
    manifest['visible_files'].each.with_object({}) do |(filename, file), memo|
      memo[filename] = file['content']
    end
  end

  def image_name
    manifest['image_name']
  end

  def max_seconds
    manifest['max_seconds'] || 5
  end

  def manifest
    manifests[display_name]
  end

  def manifests
    @@manifests ||= begin
      manifests_filename = "#{__dir__}/data/languages_start_points.manifests.json"
      manifests = File.read(manifests_filename)
      JSON.parse(manifests)['manifests']
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 4. call results

  def stdout
    run_result['stdout']['content']
  end

  def stderr
    run_result['stderr']['content']
  end

  def status
    run_result['status']
  end

  def outcome
    run_result['outcome']
  end

  def pulling?
    outcome == 'pulling'
  end

  def red?
    outcome == 'red'
  end

  def amber?
    outcome == 'amber'
  end

  def green?
    outcome == 'green'
  end

  def timed_out?
    outcome == 'timed_out'
  end

  def faulty?
    outcome == 'faulty'
  end

  def created
    run_result['created']
  end

  def changed
    run_result['changed']
  end

  def pretty_result(tag)
    ["CONTEXT:#{tag}:",
     JSON.pretty_generate(run_result)].join("\n")
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 5. custom asserts

  def assert_cyber_dojo_sh(script)
    run_cyber_dojo_sh({
                        changed: { 'cyber-dojo.sh' => script }
                      })
    refute timed_out?, pretty_result(:timed_out)
  end

  def assert_sha(sha)
    assert sha.is_a?(String), :class
    assert_equal 40, sha.size, :size
    sha.each_char do |ch|
      assert lo_hex?(ch), ch
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 6. misc helpers

  def on_client(&block)
    return unless ENV['CONTEXT'] == 'client'

    block.call
  end

  def on_server(&block)
    return unless ENV['CONTEXT'] == 'server'

    block.call
  end

  def logged?(message)
    log.include?(message)
  end

  def log
    context.logger.logged
  end

  def assert_json_line(line, expected)
    assert_equal(expected, JSON.parse(line, symbolize_names: true))
  end

  def uid
    41_966
  end

  def group
    'sandbox'
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

  def lo_hex?(char)
    '0123456789abcdef'.include?(char)
  end

  def intact(content)
    { 'content' => content, 'truncated' => false }
  end

  def captured_stdout_stderr
    begin
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = StringIO.new('', 'w')
      $stderr = StringIO.new('', 'w')
      yield
      stdout = $stdout.string
      stderr = $stderr.string
    ensure
      $stderr = old_stderr
      $stdout = old_stdout
    end
    [stdout, stderr]
  end
end
