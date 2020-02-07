# frozen_string_literal: true
require_relative 'hex_mini_test'
require_relative '../src/http_adapter'
require_relative '../src/languages_start_points'
require_relative '../src/runner'
require 'json'

class TestBase < HexMiniTest

  def initialize(arg)
    super(arg)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def self.multi_os_test(hex_suffix, *lines, &block)
    alpine_lines = ['[Alpine]'] + lines
    test(hex_suffix+'0', *alpine_lines, &block)
    ubuntu_lines = ['[Ubuntu]'] + lines
    test(hex_suffix+'1', *ubuntu_lines, &block)
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
    hex_test_id[0..5]
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

  def display_name
    case os
    when :C_assert     then 'C (gcc), assert'
    when :Ubuntu       then 'D, unittest'
    else                    'C#, NUnit'
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def os
    if hex_test_name.start_with? '[C,assert]'
      return :C_assert
    elsif hex_test_name.start_with? '[Ubuntu]'
      return :Ubuntu
    else # default
      :Alpine
    end
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
