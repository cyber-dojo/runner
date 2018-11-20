require_relative 'hex_mini_test'
require_relative '../../src/external'
require_relative '../../src/rag_lambda_cache'
require_relative '../../src/runner'

class TestBase < HexMiniTest

  def external
    @external ||= External.new
  end

  def cache
    @cache ||= RagLambdaCache.new
  end

  def runner
    Runner.new(external, cache)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def sha
    runner.sha
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def kata_new
    runner.kata_new(image_name, id, starting_files)
    @previous_files = starting_files
  end

  def kata_old
    runner.kata_old(image_name, id)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def run_cyber_dojo_sh(named_args = {})

    unchanged_files = @previous_files

    created_files = defaulted_arg(named_args, :created_files, {})
    created_files.keys.each do |filename|
      diagnostic = "#{filename} is not a created_file (it already exists)"
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

    args = []
    args << image_name
    args << id
    args << created_files
    args << deleted_files
    args << unchanged_files
    args << changed_files
    args << defaulted_arg(named_args, :max_seconds, 10)
    @result = runner.run_cyber_dojo_sh(*args)

    @previous_files = [ *unchanged_files, *changed_files, *created_files ].to_h
    nil
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def defaulted_arg(named_args, arg_name, arg_default)
    named_args.key?(arg_name) ? named_args[arg_name] : arg_default
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :result

  def stdout
    result[__method__]['content']
  end

  def stderr
    result[__method__]['content']
  end

  def colour
    result[__method__]
  end

  def created_files
    result[__method__]
  end

  def deleted_files
    result[__method__]
  end

  def changed_files
    result[__method__]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_stdout(expected)
    assert_equal expected, stdout, result
  end
  def refute_stdout(unexpected)
    refute_equal unexpected, stdout, result
  end

  def assert_stderr(expected)
    assert_equal expected, stderr, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_timed_out
    assert timed_out?, result
  end

  def refute_timed_out
    refute timed_out?, result
  end

  def timed_out?
    colour == 'timed_out'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_colour(expected)
    assert_equal expected, colour, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh(script)
    named_args = {
      :changed_files => { 'cyber-dojo.sh' => file(script) }
    }
    run_cyber_dojo_sh(named_args)
    refute_timed_out
    stdout.strip
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def image_name
    manifest['image_name']
  end

  def id
    hex_test_id[0..5]
  end

  def uid
    41966
  end

  def group
    'sandbox'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def starting_files
    Hash[manifest['visible_filenames'].collect { |filename|
      [filename, file(IO.read("#{starting_files_dir}/#{filename}"))]
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

  def self.multi_os_test(hex_suffix, *lines, &block)
    alpine_lines = ['[Alpine]'] + lines
    test(hex_suffix+'0', *alpine_lines, &block)
    ubuntu_lines = ['[Ubuntu]'] + lines
    test(hex_suffix+'1', *ubuntu_lines, &block)
  end

  def all_OSes
    [ :Alpine, :Ubuntu, :Debian ]
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

  def with_captured_log
    @log = ''
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('', 'w')
      yield
      @log = $stdout.string
    ensure
      $stdout = old_stdout
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def file(content, truncated = false)
    { 'content' => content,
      'truncated' => truncated
    }
  end

end
