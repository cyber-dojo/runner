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

  def self.alpine_test(id_suffix, *lines, &block)
    define_test(:Alpine, 'C#, NUnit', id_suffix, *lines, &block)
  end

  def self.ubuntu_test(id_suffix, *lines, &block)
    define_test(:Ubuntu, 'VisualBasic, NUnit', id_suffix, *lines, &block)
  end

  def self.multi_os_test(id_suffix, *lines, &block)
    alpine_test(id_suffix+'0', *lines, &block)
    ubuntu_test(id_suffix+'1', *lines, &block)
  end

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

    args = []
    args << defaulted_arg(named_args, :image_name, image_name)
    args << defaulted_arg(named_args, :id,         id)
    args << [ *created_files, *unchanged_files, *changed_files ].to_h
    args << defaulted_arg(named_args, :max_seconds, 10)

    @result = runner.run_cyber_dojo_sh(*args)

    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :result

  def stdout
    result['run_cyber_dojo_sh']['stdout']['content']
  end

  def stderr
    result['run_cyber_dojo_sh']['stderr']['content']
  end

  def status
    result['run_cyber_dojo_sh']['status']
  end

  def created
    result['run_cyber_dojo_sh']['created']
  end

  def deleted
    result['run_cyber_dojo_sh']['deleted']
  end

  def changed
    result['run_cyber_dojo_sh']['changed']
  end

  def timed_out?
    result['run_cyber_dojo_sh']['timed_out']
  end

  def traffic_light
    result['colour']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh(sh_script)
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => sh_script }
    })
    refute timed_out?, result
    assert_equal '', stderr
    stdout
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_name
    manifest['image_name']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def id
    id58[0..5]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def starting_files
    manifest['visible_files'].map do |filename,file|
      [ filename, file['content'] ]
    end.to_h
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def manifest
    @manifest ||= languages_start_points.manifest(display_name)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def hiker_c
    starting_files['hiker.c']
  end

  private

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

end
