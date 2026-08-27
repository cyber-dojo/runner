require_relative '../test_base'
require_relative '../data/python_pytest'
require_code 'traffic_light'
require_code 'tarfile_writer'
require_code 'externals/docker_socket'

class TrafficLightTest < TestBase

  def id58_setup
    set_context(logger: StdoutLoggerSpy.new)
  end

  # - - - - - - - - - - - - - - - - -
  # red, amber, green

  test '22ECB0', %w[red traffic-light] do
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

  test '22ECB1', %w[amber traffic-light] do
    rag = 'lambda{|so,se,st| :amber }'
    daemon_spy_lambda_source(rag)

    traffic_light_colour(stdout: Test::Data::PythonPytest::STDOUT_AMBER)
    assert_amber
    assert_no_fault_info
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB2', %w[green traffic-light] do
    rag = 'lambda{|so,se,st| :green }'
    daemon_spy_lambda_source(rag)

    traffic_light_colour(stdout: Test::Data::PythonPytest::STDOUT_GREEN)
    assert_green
    assert_no_fault_info
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB3', %w[read rag-lambda message is logged once] do
    rag = 'lambda{|so,se,st| :green }'
    daemon_spy_lambda_source(rag)

    assert_log_read_rag_lambda_count 0
    traffic_light_colour(stdout: Test::Data::PythonPytest::STDOUT_GREEN)
    assert_log_read_rag_lambda_count 1
    traffic_light_colour(stdout: Test::Data::PythonPytest::STDOUT_RED)
    assert_log_read_rag_lambda_count 1
  end

  # - - - - - - - - - - - - - - - - -

  test '22ExJ5', %w[lambdas are cached] do
    rag = 'lambda{|so,se,st| :green }'
    daemon_spy_lambda_source(rag)

    image_name = python_pytest_image_name
    f1 = traffic_light.send('[]', image_name)
    f2 = traffic_light.send('[]', image_name)
    assert_equal f1.object_id, f2.object_id, :caching
  end

  # - - - - - - - - - - - - - - - - -

  test '22ExJ7', %w[lambda status argument is an integer in a string] do
    rag = 'lambda{|so,se,st| :red }'
    daemon_spy_lambda_source(rag)

    traffic_light_colour(status: '0')
    assert_red
    assert_no_fault_info
  end

  # - - - - - - - - - - - - - - - - -

  test '22ExJ8', %w(
  | rag-lambda can return a string or a symbol (Postel's Law)
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
  | a real read against the real daemon,
  | which is the only thing that says the daemon will copy a file out of a
  | container it has created and never started, and that what comes back
  | parses as a tar holding the rag-lambda, neither of which a stub can judge.
  | That the DELETE is issued is 22ECB0's to say: the suite is parallel and
  | creates real containers elsewhere, so counting them here would be flaky
  | rather than stricter
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      http: DockerSocket.new
    )
    # On the node before the tests start, put there by
    # bin/setup_dependent_images.sh, and carrying a rag-lambda file.
    image_name = 'ghcr.io/cyber-dojo-languages/gcc_assert:2733119'

    fn = traffic_light.send('[]', image_name)

    assert fn.is_a?(Proc), fn.class.name
    assert_logged("Read red-amber-green lambda from #{image_name}", :real_read)
  end

  # - - - - - - - - - - - - - - - - -
  # faulty

  test '22ECB4', %w(
  | image_name with missing rag-lambda file,
  | always gives colour==faulty,
  | adds info to log
  ) do
    daemon_spy_missing_lambda

    traffic_light_colour

    assert_faulty
    context = 'image_name must have /usr/local/bin/red_amber_green.rb file'
    assert_missing_lambda_logged(context)
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB5', %w(
  | rag-lambda which raises when eval'd,
  | gives colour==faulty,
  | adds message to log
  ) do
    lambda_source = 'not-a-lambda'
    daemon_spy_lambda_source(lambda_source)

    traffic_light_colour

    assert_faulty
    assert_bad_lambda_logged(
      "exception when eval'ing lambda source",
      lambda_source,
      'SyntaxError',
      ["(eval at /runner/source/traffic_light.rb:112):1: syntax error found",
       '> 1 | not-a-lambda',
       '    | ^~~ expected an expression after `not`',
       ''].join("\n")
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '22ECB6', %w(
  | rag-lambda which raises when called,
  | gives colour==faulty,
  | adds message to log
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
  | rag-lambda with too few parameters,
  | gives colour==faulty,
  | adds message to log
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
  | rag-lambda with too many parameters,
  | gives colour==faulty,
  | adds message to log
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
  | rag-lambda which returns non red/amber/green,
  | gives colour==faulty,
  | adds message to log
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

  private

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
