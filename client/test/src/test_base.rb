require_relative 'hex_mini_test'
require_relative '../../src/runner_service'
require 'json'

class TestBase < HexMiniTest

  def self.multi_os_test(hex_suffix, *lines, &block)
    alpine_lines = ['[Alpine]'] + lines
    test(hex_suffix+'0', *alpine_lines, &block)
    ubuntu_lines = ['[Ubuntu]'] + lines
    test(hex_suffix+'1', *ubuntu_lines, &block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def runner
    RunnerService.new
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def kata_new(named_args = {})
    args = common_args(named_args)
    args << defaulted_arg(named_args, :starting_files, starting_files)
    @all_files = args[-1]
    runner.kata_new(*args)
  end

  def kata_old(named_args={})
    runner.kata_old(*common_args(named_args))
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  #def avatar_new(named_args = {})
  #  args = common_args(named_args)
  #  args << defaulted_arg(named_args, :avatar_name,    avatar_name)
  #  args << defaulted_arg(named_args, :starting_files, starting_files)
  #  result = runner.avatar_new(*args)
  #  @avatar_name = args[-2]
  #  @all_files = args[-1]
  #  result
  #end

  #def avatar_old(named_args = {})
  #  args = common_args(named_args)
  #  args << defaulted_arg(named_args, :avatar_name, avatar_name)
  #  runner.avatar_old(*args)
  #end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

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

    args = common_args(named_args)
    args << new_files
    args << defaulted_arg(named_args, :deleted_files, {})
    args << unchanged_files
    args << changed_files
    args << defaulted_arg(named_args, :max_seconds, 10)

    @result = runner.run_cyber_dojo_sh(*args)

    @all_files = [ *new_files, *unchanged_files, *changed_files ].to_h
    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :result

  def stdout
    result['stdout']
  end

  def stderr
    result['stderr']
  end

  def colour
    result['colour']
  end

  def new_files
    result['new_files']
  end

  def deleted_files
    result['deleted_files']
  end

  def changed_files
    result['changed_files']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def red?
    colour == 'red'
  end

  def amber?
    colour == 'amber'
  end

  def green?
    colour == 'green'
  end

  def timed_out?
    colour == 'timed_out'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh(sh_script)
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => sh_script }
    })
    refute timed_out?, result
    assert_equal '', stderr
    stdout.strip
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_name
    @image_name || manifest['image_name']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def kata_id
    hex_test_id + '0' * (10 - hex_test_id.length)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def starting_files
    Hash[manifest['visible_filenames'].collect { |filename|
      [filename, IO.read("#{starting_files_dir}/#{filename}")]
    }]
  end

  def manifest
    @manifest ||= JSON.parse(IO.read("#{starting_files_dir}/manifest.json"))
  end

  def starting_files_dir
    "/app/test/start_files/#{os}"
  end

  def os
    if hex_test_name.start_with? '[C,assert]'
      return :C_assert
    elsif hex_test_name.start_with? '[Ubuntu]'
      return :Ubuntu
    else # [Alpine] || default
      :Alpine
    end
  end

  private

  def common_args(named_args)
    [ defaulted_arg(named_args, :image_name, image_name),
      defaulted_arg(named_args, :kata_id,    kata_id)
    ]
  end

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def in_kata
    kata_new
    begin
      yield
    ensure
      kata_old
    end
  end

end
