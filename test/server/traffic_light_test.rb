require_relative '../test_base'
require_relative '../data/python_pytest'
require_code 'traffic_light'
require_code 'externals/docker_socket'
require_lib 'tarfile_writer'

class TrafficLightTest < TestBase

  def id58_setup
    set_context(logger: StdoutLoggerSpy.new)
  end

  # - - - - - - - - - - - - - - - - -
  # red, amber, green

  test '22ECB0', %w[
  | The image's rag-lambda answers :red.
  | The traffic light is red, and there is no fault info.
  | The lambda is read out of a container made from the image alone.
  | That container is given no name.
  | It is created, read from, and removed, and never started.
  | The daemon copies a file out of a container that has never run.
  | Those three calls are all the daemon is asked for.
  ] do
    daemon_spy_lambda_source('lambda{|so,se,st| :red }')

    traffic_light_colour(stdout: Test::Data::PythonPytest::STDOUT_RED)
    assert_red
    assert_no_fault_info

    # Nothing is started. The container exists only for the daemon to copy a
    # file out of, which it will do for one that has never run.
    assert_equal [:create_container, { 'Image' => python_pytest_image_name }, nil], docker.calls[0]
    assert_equal [:read_file, 'c0ffee', RAG_LAMBDA_FILENAME], docker.calls[1]
    assert_equal [:remove_container, 'c0ffee'], docker.calls[2]
    assert_equal 3, docker.calls.size
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB1', %w[
  | The image's rag-lambda answers :amber.
  | The traffic light is amber, and there is no fault info.
  | The stdout is a real pytest run's, though this lambda ignores it.
  ] do
    rag = 'lambda{|so,se,st| :amber }'
    daemon_spy_lambda_source(rag)

    traffic_light_colour(stdout: Test::Data::PythonPytest::STDOUT_AMBER)
    assert_amber
    assert_no_fault_info
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB2', %w[
  | The image's rag-lambda answers :green.
  | The traffic light is green, and there is no fault info.
  | The stdout is a real pytest run's, though this lambda ignores it.
  ] do
    rag = 'lambda{|so,se,st| :green }'
    daemon_spy_lambda_source(rag)

    traffic_light_colour(stdout: Test::Data::PythonPytest::STDOUT_GREEN)
    assert_green
    assert_no_fault_info
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB3', %w[
  | Nothing has been logged about reading the rag-lambda.
  | A colour is asked for, and the read is logged once.
  | A second colour is asked for, and nothing more is logged.
  | The lambda is read from the image once, not once per colour.
  ] do
    rag = 'lambda{|so,se,st| :green }'
    daemon_spy_lambda_source(rag)

    assert_log_read_rag_lambda_count 0
    traffic_light_colour(stdout: Test::Data::PythonPytest::STDOUT_GREEN)
    assert_log_read_rag_lambda_count 1
    traffic_light_colour(stdout: Test::Data::PythonPytest::STDOUT_RED)
    assert_log_read_rag_lambda_count 1
  end

  # - - - - - - - - - - - - - - - - -

  test '22ExJ5', %w[
  | Two colours are asked for, from one image.
  | Both are green.
  | The lambda is compiled once.
  | The daemon is asked for three calls: the create, the read, the removal.
  | Those three are all of them, so the image was read once.
  ] do
    daemon_spy_lambda_source(counted_lambda_source)

    2.times { traffic_light_colour(stdout: Test::Data::PythonPytest::STDOUT_GREEN) }

    assert_green
    assert_equal 1, EvalCounter.count(id58)
    # The create, the archive read and the removal, once between them.
    assert_equal 3, docker.calls.size
  end

  # - - - - - - - - - - - - - - - - -

  test '22ExJ7', %w[
  | The status arrives as a string, as the payload carries it.
  | The lambda is handed an integer, and answers green only for 0.
  | The traffic light is green, and there is no fault info.
  ] do
    rag = 'lambda{|so,se,st| st == 0 ? :green : :red }'
    daemon_spy_lambda_source(rag)

    traffic_light_colour(status: '0')
    assert_green
    assert_no_fault_info
  end

  # - - - - - - - - - - - - - - - - -

  test '22ExJ8', %w(
  | A rag-lambda answers the string 'red'.
  | The traffic light is red, and there is no fault info.
  | Another rag-lambda answers the symbol :red.
  | That traffic light is red too, and there is no fault info.
  | A string and a symbol are accepted alike.
  ) do
    rag = "lambda{|so,se,st| 'red' }"
    daemon_spy_lambda_source(rag)
    traffic_light_colour
    assert_red
    assert_no_fault_info

    rag = 'lambda{|so,se,st| :red }'
    daemon_spy_lambda_source(rag)
    traffic_light_colour
    assert_red
    assert_no_fault_info
  end

  # - - - - - - - - - - - - - - - - -

  test '22ExJ9', %w(
  | The read goes to the real daemon.
  | The image is gcc_assert, which carries a rag-lambda of its own.
  | The colour is one of red, amber, green.
  | Which of the three is that lambda's business, not this test's.
  | Answering one of them at all is what says the read compiled.
  | The read is logged.
  | A stub cannot judge a copy out of a never-started container, or a tar.
  | Only the daemon can.
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      http: DockerSocket.new
    )
    # On the node before the tests start, put there by
    # bin/setup_dependent_images.sh, and carrying a rag-lambda file.
    image_name = 'ghcr.io/cyber-dojo-languages/gcc_assert:2733119'

    colour, fault_info = traffic_light.colour_from_image(image_name, 'unused', 'unused', 0)

    # Which colour is the image's own lambda's business; that it answers one of
    # the three at all is what says a real read compiled into a working lambda.
    assert_includes %w[red amber green], colour, fault_info
    assert_logged("Read red-amber-green lambda from #{image_name}", :real_read)
  end

  # - - - - - - - - - - - - - - - - -
  # faulty

  test '22ECB4', %w(
  | The image holds no rag-lambda file.
  | The daemon answers the read 404.
  | The traffic light is faulty.
  | The log says the image must hold /usr/local/bin/red_amber_green.rb.
  ) do
    daemon_spy_missing_lambda

    traffic_light_colour

    assert_faulty
    context = 'image_name must have /usr/local/bin/red_amber_green.rb file'
    assert_missing_lambda_logged(context)
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB5', %w(
  | The image's rag-lambda source is not a lambda at all.
  | Compiling it raises a SyntaxError.
  | The traffic light is faulty.
  | The log names the source, the exception class, and what ruby said of it.
  | That message is asserted whole, down to the caret line.
  | A ruby upgrade that rewords it fails here.
  ) do
    lambda_source = 'not-a-lambda'
    daemon_spy_lambda_source(lambda_source)

    traffic_light_colour

    assert_faulty
    assert_bad_lambda_logged(
      "exception when eval'ing lambda source",
      lambda_source,
      'SyntaxError',
      ["(eval at /runner/source/traffic_light.rb:132):1: syntax error found",
       '> 1 | not-a-lambda',
       '    | ^~~ expected an expression after `not`',
       ''].join("\n")
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB6', %w(
  | The image's rag-lambda compiles, and raises when it is called.
  | The traffic light is faulty.
  | The log names the source, the exception class, and its message.
  | The log says the exception came from calling the lambda.
  | 22ECB5's says it came from compiling one.
  ) do
    lambda_source = "lambda{ |so,se,st| fail RuntimeError, '42' }"
    daemon_spy_lambda_source(lambda_source)

    traffic_light_colour

    assert_faulty
    assert_bad_lambda_logged(
      'exception when calling lambda source',
      lambda_source,
      'RuntimeError',
      '42'
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB7', %w(
  | The image's rag-lambda takes two parameters.
  | A rag-lambda is called with three: stdout, stderr and status.
  | Calling it raises an ArgumentError, given 3 and expecting 2.
  | The traffic light is faulty.
  | The log names the source, the exception class, and its message.
  ) do
    lambda_source = 'lambda{ |_a,_b| :red }'
    daemon_spy_lambda_source(lambda_source)

    traffic_light_colour

    assert_faulty
    assert_bad_lambda_logged(
      'exception when calling lambda source',
      lambda_source,
      'ArgumentError',
      'wrong number of arguments (given 3, expected 2)'
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB8', %w(
  | The image's rag-lambda takes four parameters.
  | Calling it with three raises an ArgumentError, given 3 and expecting 4.
  | The traffic light is faulty.
  | The log names the source, the exception class, and its message.
  ) do
    lambda_source = 'lambda{ |_a,_b,_c,_d| :red }'
    daemon_spy_lambda_source(lambda_source)

    traffic_light_colour

    assert_faulty
    assert_bad_lambda_logged(
      'exception when calling lambda source',
      lambda_source,
      'ArgumentError',
      'wrong number of arguments (given 3, expected 4)'
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB9', %w(
  | The image's rag-lambda compiles, and answers :orange.
  | A traffic light is one of red, amber, green.
  | The traffic light is faulty.
  | The log names the colour the lambda gave, and the three it can be.
  | It names the source too.
  ) do
    lambda_source = [
      'lambda {|so,se,st|',
      '  :orange',
      '}'
    ].join("\n")
    daemon_spy_lambda_source(lambda_source)

    traffic_light_colour

    assert_faulty
    assert_illegal_colour_logged(
      "illegal colour; must be one of ['red','amber','green']",
      'orange',
      lambda_source
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '22ExJ0', %w[
  | The rag-lambda source is handed in, not read from an image.
  | Three colours are asked for from that one source.
  | All three are red, and none reports fault info.
  | The source is compiled once.
  | A rag-lambda source belongs to a start-point, not to a kata.
  | So the same few sources arrive over and over, and caching them pays.
  ] do
    3.times do
      colour, fault_info = traffic_light.colour_from_lambda(counted_lambda_source, assertion_failed_stdout, '', 134)
      assert_equal 'red', colour, log
      assert_equal({}, fault_info, log)
    end

    assert_equal 1, EvalCounter.count(id58)
  end

  # Counts how often a source is compiled, by being called while it is being
  # eval'd rather than when the lambda it answers is called. Reachable from
  # Empty.binding because TrafficLightTest is a top-level constant.
  #
  # Counted per token rather than in one tally, because parallelize_me! runs
  # the tests that use this in threads of one process, so a single tally would
  # have each of them counting the others' evals.
  class EvalCounter
    @counts = {}
    @mutex = Mutex.new

    def self.bump(token)
      @mutex.synchronize { @counts[token] = (@counts[token] || 0) + 1 }
    end

    def self.count(token)
      @mutex.synchronize { @counts[token] || 0 }
    end
  end

  private

  # The gcc_assert start-point's rag-lambda, as
  # test/data/languages_start_points.manifests.json carries it, with one line
  # added that says when it is compiled.
  def counted_lambda_source
    [
      "TrafficLightTest::EvalCounter.bump('#{id58}')",
      'lambda { |stdout, stderr, status|',
      '  output = stdout + stderr',
      '  return :green if status == 0',
      '  return :red   if /(.*)Assertion(.*)failed/.match(output)',
      '  return :amber',
      '}'
    ].join("\n")
  end

  # What a failed C assert says, and the status the abort answers with.
  def assertion_failed_stdout
    "test: hiker.tests.c:9: test_answer: Assertion `answer() == 42' failed.\n"
  end

  def traffic_light_colour(options = {})
    @image_name = python_pytest_image_name
    @stdout = options.delete(:stdout) || Test::Data::PythonPytest::STDOUT_RED
    @stderr = options.delete(:stderr) || 'unused'
    @status = options.delete(:status) || 0
    @outcome, @fault_info = *traffic_light.colour_from_image(@image_name, @stdout, @stderr, @status)
  end

  def python_pytest_image_name
    'cyberdojofoundation/python_pytest'
  end

  def traffic_light
    @traffic_light ||= TrafficLight.new(context)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def assert_red
    assert_equal 'red', @outcome, log
  end

  def assert_amber
    assert_equal 'amber', @outcome, log
  end

  def assert_green
    assert_equal 'green', @outcome, log
  end

  def assert_faulty
    assert_equal 'faulty', @outcome, log
  end

  def assert_no_fault_info
    assert_equal({}, @fault_info, log)
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def assert_log_read_rag_lambda_count(expected)
    lines = log.split("\n")
    actual = read_red_amber_green_lambda_message_count(lines)
    assert_equal expected, actual, lines
  end

  def read_red_amber_green_lambda_message_count(lines)
    message = "Read red-amber-green lambda from #{python_pytest_image_name}"
    lines.count { |line| line.include?(message) }
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  RAG_LAMBDA_FILENAME = '/usr/local/bin/red_amber_green.rb'

  # An image with no rag-lambda file in it. The archive endpoint answers 404
  # for a path the container does not hold, in the wording the daemon uses.
  def daemon_spy_missing_lambda
    set_context(
      logger: StdoutLoggerSpy.new,
      docker: DockerDaemonSpy.new(
        [
          [201, '{"Id":"c0ffee"}'],
          [404, missing_lambda_body],
          [204, '']
        ]
      )
    )
  end

  def missing_lambda_body
    message = "Could not find the file #{RAG_LAMBDA_FILENAME} in container c0ffee"
    %({"message":"#{message}"})
  end

  # The daemon answering the three calls that read one file out of an image:
  # a container created and never started, the tar the archive endpoint
  # answers, and the removal.
  def daemon_spy_lambda_source(source)
    tar = TarFile::Writer.new
    tar.write('red_amber_green.rb', source)
    set_context(
      logger: StdoutLoggerSpy.new,
      docker: DockerDaemonSpy.new(
        [
          [201, '{"Id":"c0ffee"}'],
          [200, tar.tar_file],
          [204, '']
        ]
      )
    )
  end


  # - - - - - - - - - - - - - - - - - - - - - -

  def assert_missing_lambda_logged(context)
    assert_call_info_logged(
      context: context,
      image_name: python_pytest_image_name,
      code: 404,
      body: missing_lambda_body
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def assert_bad_lambda_logged(context, lambda_source, klass, message)
    assert_call_info_logged(
      context: context,
      lambda_source: lambda_source.lines,
      class: klass,
      message: message.lines
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def assert_illegal_colour_logged(context, illegal_colour, lambda_source)
    assert_call_info_logged(
      context: context,
      illegal_colour: illegal_colour,
      lambda_source: lambda_source.lines
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def assert_call_info_logged(properties)
    assert_logged_fault_info({
                               call: 'TrafficLight.colour_from_image(image_name,stdout,stderr,status)',
                               args: {
                                 image_name: @image_name,
                                 stdout: @stdout.lines,
                                 stderr: @stderr.lines,
                                 status: @status
                               },
                               exception: properties
                             })
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def assert_logged_fault_info(hash)
    json = JSON.pretty_generate(hash)
    assert_logged(json, :logged)
    assert_equal hash, @fault_info, :fault_info
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def assert_logged(expected, context)
    assert logged?(expected), "\nLOG:#{log}:\nCONTEXT:#{context}:\nEXPECTED:#{expected}:\n"
  end
end
