# frozen_string_literal: true
require_relative '../id58_test_base'
require_source 'languages_start_points'
require_source 'runner'
require 'json'

class TestBase < Id58TestBase

  def initialize(arg)
    super(arg)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 1. test on one or many OS

  def self.test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
  end

  def self.multi_os_test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
    ubuntu_test(id_suffix, *lines, &block)
  end

  # OS specific tests

  def self.alpine_test(id_suffix, *lines, &block)
    self.csharp_nunit_test(id_suffix, *lines, &block)
  end

  def self.ubuntu_test(id_suffix, *lines, &block)
    self.visual_basic_nunit_test(id_suffix, *lines, &block)
  end

  # Language Test Framework specific tests

  def self.csharp_nunit_test(id_suffix, *lines, &block)
    define_test(:Alpine, 'C#, NUnit', id_suffix, *lines, &block)
  end

  def self.c_assert_test(id_suffix, *lines, &block)
    define_test(:Debian, 'C (gcc), assert', id_suffix, *lines, &block)
  end

  def self.visual_basic_nunit_test(id_suffix, *lines, &block)
    define_test(:Ubuntu, 'VisualBasic, NUnit', id_suffix, *lines, &block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 2. the http-services and arguments

  def runner
    hostname = 'runner-server'
    port = 4597
    Runner.new(hostname, port)
  end

  def languages_start_points
    hostname = 'languages-start-points'
    port = 4524
    LanguagesStartPoints.new(hostname, port)
  end

  def id
    id58[0..5]
  end

  def image_name
    manifest['image_name']
  end

  def starting_files
    manifest['visible_files'].each.with_object({}) do |(filename,file),memo|
      memo[filename] = file['content']
    end
  end

  def manifest
    @manifest ||= languages_start_points.manifest(display_name)
  end

  def hiker_c
    starting_files['hiker.c']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 3. runner helper

  def run_cyber_dojo_sh(named_args = {})

    unchanged_files = starting_files

    changed_files = defaulted_arg(named_args, :changed_files, {})
    changed_files.keys.each do |filename|
      diagnostic = "#{filename} is not a changed_file (it does not already exist)"
      assert unchanged_files.keys.include?(filename), diagnostic
      unchanged_files.delete(filename)
    end

    created_files = defaulted_arg(named_args, :created_files, {})
    created_files.keys.each do |filename|
      diagnostic = "#{filename} is not a created_file (it already exists)"
      refute unchanged_files.keys.include?(filename), diagnostic
    end

    id = defaulted_arg(named_args, :id, id)
    files = [ *created_files, *unchanged_files, *changed_files ].to_h
    manifest = {
      'image_name' => defaulted_arg(named_args, :image_name, image_name),
      'max_seconds' => defaulted_arg(named_args, :max_seconds, 10)
    }
    @result = runner.run_cyber_dojo_sh(id, files, manifest)
    nil
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  attr_reader :result

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 4. custom asserts

  def assert_cyber_dojo_sh(sh_script)
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => sh_script }
    })
    refute timed_out?, result
    assert stderr.empty?, stderr
    stdout
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # 5. results from runner.run_cyber_dojo_sh call

  def stdout; @result['stdout']['content']; end
  def stderr; @result['stderr']['content']; end
  def status; @result['status']; end

  def timed_out?; @result['timed_out']; end
  def colour; @result['colour']; end

  def created; @result['created']; end
  def deleted; @result['deleted']; end
  def changed; @result['changed']; end

end
