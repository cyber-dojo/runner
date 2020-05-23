# frozen_string_literal: true
require_relative '../id58_test_base'
require_src 'http_adapter'
require_src 'languages_start_points'
require_src 'runner'
require 'json'

class TestBase < Id58TestBase

  def initialize(arg)
    super(arg)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def self.test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
  end

  def self.multi_os_test(id_suffix, *lines, &block)
    alpine_test(id_suffix, *lines, &block)
    ubuntu_test(id_suffix, *lines, &block)
  end

  # OS specific

  def self.alpine_test(id_suffix, *lines, &block)
    define_test(:Alpine, 'C#, NUnit', id_suffix, *lines, &block)
  end

  def self.ubuntu_test(id_suffix, *lines, &block)
    define_test(:Ubuntu, 'VisualBasic, NUnit', id_suffix, *lines, &block)
  end

  # Language Test Framework specific

  def self.c_assert_test(id_suffix, *lines, &block)
    define_test(:Debian, 'C (gcc), assert', id_suffix, *lines, &block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def runner
    Runner.new(http_adapter )
  end

  def languages_start_points
    LanguagesStartPoints.new(http_adapter)
  end

  def http_adapter
    HttpAdapter.new
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh(sh_script)
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => sh_script }
    })
    refute timed_out?, result
    assert stderr.empty?, stderr
    stdout
  end

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

    args = {
      'id' => defaulted_arg(named_args, :id, id),
      'files' => [ *created_files, *unchanged_files, *changed_files ].to_h,
      'manifest' => {
        'image_name' => defaulted_arg(named_args, :image_name, image_name),
        'max_seconds' => defaulted_arg(named_args, :max_seconds, 10),
        'hidden_filenames' => defaulted_arg(named_args, :hidden_filenames, nil)
      }
    }
    @result = runner.run_cyber_dojo_sh(args)
    nil
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :result

  def run_result
    result['run_cyber_dojo_sh']
  end

  def stdout
    run_result['stdout']['content']
  end

  def stderr
    run_result['stderr']['content']
  end

  def status
    run_result['status']
  end

  def created
    run_result['created']
  end

  def deleted
    run_result['deleted']
  end

  def changed
    run_result['changed']
  end

  def timed_out?
    run_result['timed_out']
  end

  def colour
    run_result['colour']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def id
    id58[0..5]
  end

  def image_name
    manifest['image_name']
  end

  def hidden_filenames
    manifest['hidden_filenames']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

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

end
