require_relative 'hex_mini_test'
require_relative 'rack_request_stub'
require_relative '../../src/all_avatars_names'
require_relative '../../src/external'
require_relative '../../src/rack_dispatcher'
require 'json'

class TestBase < HexMiniTest

  def rack
    @rack ||= RackDispatcher.new(external, RackRequestStub)
  end

  def external
    @external ||= External.new
  end

  def bash
    external.bash
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def self.multi_os_test(hex_suffix, *lines, &block)
    alpine_lines = ['[Alpine]'] + lines
    test(hex_suffix+'0', *alpine_lines, &block)
    ubuntu_lines = ['[Ubuntu]'] + lines
    test(hex_suffix+'1', *ubuntu_lines, &block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def rack_call(method_name, args = {})
    args['image_name'] = image_name
    args['kata_id'] = kata_id
    env = { body:args.to_json, path_info:method_name.to_s }
    result = rack.call(env)
    @json = JSON.parse(result[2][0])
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def kata_new
    rack_call(__method__)
  end

  def kata_old
    rack_call(__method__)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def avatar_new(name = 'salmon')
    args = { avatar_name:name, starting_files:starting_files }
    rack_call(__method__, args)
    @avatar_name = name
    @previous_files = starting_files
  end

  def avatar_old(name = avatar_name)
    args = { avatar_name:name }
    rack_call(__method__, args)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(named_args = {})

    unchanged_files = @previous_files

    new_files = defaulted_arg(named_args, :new_files, {})
    new_files.keys.each do |filename|
      diagnostic = "#{filename} is not a new_file (it already exists)"
      refute unchanged_files.keys.include?(filename), diagnostic
    end

    deleted_files = defaulted_arg(named_args, :deleted_files, {})
    deleted_files.keys.each do |filename|
      diagnostic = "#{filename} is not a deleted_file (it does not already exist)"
      assert unchanged_files.keys.include?(filename), diagnostic
      unchanged_files.delete(filename)
    end

    changed_files = defaulted_arg(named_args, :changed_files, {})
    changed_files.keys.each do |filename|
      diagnostic = "#{filename} is not a changed_file (it does not already exist)"
      assert unchanged_files.keys.include?(filename), diagnostic
      unchanged_files.delete(filename)
    end

    args = {
          avatar_name:defaulted_arg(named_args, :avatar_name, avatar_name),
            new_files:new_files,
        deleted_files:deleted_files,
      unchanged_files:unchanged_files,
        changed_files:changed_files,
          max_seconds:defaulted_arg(named_args, :max_seconds, 10)
    }
    rack_call(__method__, args)
    @result = @json[__method__.to_s]

    @previous_files = [ *unchanged_files, *changed_files, *new_files ].to_h
    nil
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :result

  def files
    result[__method__.to_s]
  end

  def stdout
    result[__method__.to_s]
  end

  def stderr
    result[__method__.to_s]
  end

  def colour
    result[__method__.to_s]
  end

  def timed_out?
    colour == 'timed_out'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_stdout(expected)
    assert_equal expected, stdout, @json
  end
  def refute_stdout(unexpected)
    refute_equal unexpected, stdout, @json
  end

  def assert_stderr(expected)
    assert_equal expected, stderr, @json
  end

  def assert_timed_out
    assert timed_out?, @json
  end

  def refute_timed_out
    refute timed_out?, @json
  end

  def assert_colour(expected)
    assert_equal expected, colour, @json
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh(script)
    named_args = {
      :changed_files => { 'cyber-dojo.sh' => script }
    }
    run_cyber_dojo_sh(named_args)
    refute_timed_out
    stdout.strip
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_name
    manifest['image_name']
  end

  def kata_id
    hex_test_id + '0' * (10-hex_test_id.length)
  end

  def avatar_name
    @avatar_name
  end

  def uid
    40000 + all_avatars_names.index(avatar_name)
  end

  include AllAvatarsNames

  def group
    'cyber-dojo'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def starting_files
    Hash[manifest['visible_filenames'].collect { |filename|
      [filename, IO.read("#{starting_files_dir}/#{filename}")]
    }]
  end

  def manifest
    JSON.parse(IO.read("#{starting_files_dir}/manifest.json"))
  end

  def starting_files_dir
    "/app/test/start_files/#{os}"
  end

  def os
    return @os unless @os.nil?
    if hex_test_name.start_with? '[C,assert]'
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

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def in_kata_as(name)
    in_kata {
      as(name) {
        yield
      }
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def in_kata
    kata_new
    begin
      yield
    ensure
      kata_old
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def as(name)
    avatar_new(name)
    yield
  ensure
    avatar_old(name)
  end

end
