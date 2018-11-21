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

  def run_cyber_dojo_sh(named_args = {})

    unchanged_files = @files || starting_files

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

    @files = [ *created_files, *unchanged_files, *changed_files ].to_h

    args = []
    args << defaulted_arg(named_args, :image_name, image_name)
    args << defaulted_arg(named_args, :id,         id)
    args << @files
    args << defaulted_arg(named_args, :max_seconds, 10)

    @result = runner.run_cyber_dojo_sh(*args)

    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :result

  def stdout
    result['stdout']['content']
  end

  def stderr
    result['stderr']['content']
  end

  def colour
    result['colour']
  end

  def created
    result['created']
  end

  def deleted
    result['deleted']
  end

  def changed
    result['changed']
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
      changed_files: { 'cyber-dojo.sh' => file(sh_script) }
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

  def id
    hex_test_id[0..5]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def starting_files
    Hash[manifest['visible_filenames'].collect { |filename|
      [filename, file(IO.read("#{starting_files_dir}/#{filename}"))]
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

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  def file(content, truncated = false)
    { 'content' => content,
      'truncated' => truncated
    }
  end

end
