require_relative 'all_avatars_names'
require_relative '../hex_mini_test'
require_relative '../../src/runner_service'
require 'json'

class TestBase2 < HexMiniTest

  def runner
    RunnerService.new
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

=begin
  def image_pulled?(named_args = {})
    args = []
    args << defaulted_arg(named_args, :image_name, image_name)
    args << defaulted_arg(named_args, :kata_id,    kata_id)
    runner.image_pulled? *args
  end

  def image_pull(named_args = {})
    args = []
    args << defaulted_arg(named_args, :image_name, image_name)
    args << defaulted_arg(named_args, :kata_id,    kata_id)
    runner.image_pull *args
  end
=end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def kata_new(named_args = {})
    args = []
    args << defaulted_arg(named_args, :image_name, image_name)
    args << defaulted_arg(named_args, :kata_id,    kata_id)
    runner.kata_new *args

  end

  def kata_old(named_args={})
    args = []
    args << defaulted_arg(named_args, :image_name, image_name)
    args << defaulted_arg(named_args, :kata_id,    kata_id)
    runner.kata_old *args
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def avatar_new(named_args = {})
    args = []
    args << defaulted_arg(named_args, :image_name,     image_name)
    args << defaulted_arg(named_args, :kata_id,        kata_id)
    args << defaulted_arg(named_args, :avatar_name,    salmon)
    args << defaulted_arg(named_args, :starting_files, starting_files)
    runner.avatar_new *args
    @avatar_name = args[-2]
    @all_files = args[-1]
  end

  def avatar_old(named_args = {})
    args = []
    args << defaulted_arg(named_args, :image_name,  image_name)
    args << defaulted_arg(named_args, :kata_id,     kata_id)
    args << defaulted_arg(named_args, :avatar_name, avatar_name)
    runner.avatar_old *args
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(named_args = {})

    unchanged_files = @all_files

    changed_files = defaulted_arg(named_args, :changed_files, {})
    changed_files.keys.each do |filename|
      diagnostic = "#{filename} is not a changed_file (it does not already exist)"
      assert unchanged_files.keys.include?(filename), diagnostic
      unchanged_files.delete(filename)
    end

    new_files = defaulted_arg(named_args, :new_files, {})
    new_files.keys.each do |filename|
      diagnostic = "#{filename} is not a new_file (it already exists)"
      refute unchanged_files.keys.include?(filename), diagnostic
    end

    args = []
    args << defaulted_arg(named_args, :image_name, image_name)
    args << defaulted_arg(named_args, :kata_id, kata_id)
    args << defaulted_arg(named_args, :avatar_name, avatar_name)
    args << defaulted_arg(named_args, :deleted_filenames, [])
    args << unchanged_files
    args << changed_files
    args << new_files
    args << defaulted_arg(named_args, :max_seconds, 10)

    @quad = runner.run_cyber_dojo_sh(*args)

    @all_files = [ *unchanged_files, *changed_files, *new_files ].to_h
    nil
  end

  def salmon
    'salmon'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def stdout
    quad['stdout']
  end

  def stderr
    quad['stderr']
  end

=begin
  def status
    quad['status']
  end
=end

  def colour
    quad['colour']
  end

  def timed_out?
    colour == 'timed_out'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

=begin
  def assert_status(expected)
    assert_equal expected, status, "assert_status:#{quad}"
  end
=end

  def assert_colour(expected)
    assert_equal expected, colour, "assert_colour:#{quad}"
  end

=begin
  def assert_stdout(expected)
    assert_equal expected, stdout, "assert_stdout:#{quad}"
  end
=end

  def assert_stderr(expected)
    assert_equal expected, stderr, "assert_stderr:#{quad}"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh(script, named_args = {})
    named_args[:changed_files] = { 'cyber-dojo.sh' => script }
    assert_run_succeeds(named_args)
  end

  def assert_run_succeeds(named_args)
    run_cyber_dojo_sh(named_args)
    refute timed_out?, quad
    assert_stderr ''
    stdout.strip
  end

=begin
  def assert_run_times_out(named_args)
    run_cyber_dojo_sh(named_args)
    assert timed_out?
    assert_status 137
    assert_stdout ''
    assert_stderr ''
  end
=end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def os
    if hex_test_name.start_with? '[Ubuntu]'
      :Ubuntu
    else # [Alpine] || default
      :Alpine
    end
  end

  def image_name
    @image_name || image_for_test
  end

  INVALID_IMAGE_NAME  = '_cantStartWithSeparator'

  def kata_id
    hex_test_id + '0' * (10-hex_test_id.length)
  end

  INVALID_KATA_ID     = '675'

  def avatar_name
    @avatar_name
  end

  INVALID_AVATAR_NAME = 'sunglasses'

  def user_id
    40000 + all_avatars_names.index(avatar_name)
  end

  def group_id
    5000
  end

  def group
    'cyber-dojo'
  end

  def home_dir
    "/home/#{avatar_name}"
  end

  def sandbox_dir
    "/tmp/sandboxes/#{avatar_name}"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def starting_files
    fail 'image_name.nil? so cannot set language_dir' if image_name.nil?
    language_dir = image_name.split('/')[1]
    dir = "/app/test/start_files/#{language_dir}"
    json = JSON.parse(IO.read("#{dir}/manifest.json"))
    Hash[json['visible_filenames'].collect { |filename|
      [filename, IO.read("#{dir}/#{filename}")]
    }]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def in_kata_as(name)
    in_kata {
      as(name) {
        yield
      }
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def in_kata
    set_image_name image_for_test
    kata_new
    yield
  ensure
    kata_old
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def as(name)
    avatar_new({ avatar_name: name })
    yield
  ensure
    avatar_old({ avatar_name: name })
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def cdf
    'cyberdojofoundation'
  end

  def set_image_name(image_name)
    @image_name = image_name
  end

  def self.multi_os_test(hex_suffix, *lines, &block)
    alpine_lines = ['[Alpine]'] + lines
    test(hex_suffix+'0', *alpine_lines, &block)
    ubuntu_lines = ['[Ubuntu]'] + lines
    test(hex_suffix+'1', *ubuntu_lines, &block)
  end

  private

  include AllAvatarsNames

  def image_for_test
    case os
    when :Alpine
      "#{cdf}/gcc_assert"
    when :Ubuntu
      "#{cdf}/clangpp_assert"
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def quad
    @quad
  end

end
