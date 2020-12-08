# frozen_string_literal: true
require_relative '../test_base'
require_relative '../data/python_pytest'
require_code 'traffic_light'

module Server
  class TrafficLightTest < TestBase

    def self.id58_prefix
      '22E'
    end

    def id58_setup
      set_context(
        logger:StdoutLoggerSpy.new,
        sheller:BashShellerStub.new
      )
    end

    # - - - - - - - - - - - - - - - - -
    # red, amber, green

    test 'CB0', %w( red traffic-light ) do
      rag = "lambda{|so,se,st| :red }"
      bash_stub_capture(docker_run_command) { [rag, '', 0] }

      traffic_light_colour(stdout:Test::Data::PythonPytest::STDOUT_RED)
      assert_red
      assert_no_fault_info
    end

    # - - - - - - - - - - - - - - - - -

    test 'CB1', %w( amber traffic-light ) do
      rag = "lambda{|so,se,st| :amber }"
      bash_stub_capture(docker_run_command) { [rag, '', 0] }

      traffic_light_colour(stdout:Test::Data::PythonPytest::STDOUT_AMBER)
      assert_amber
      assert_no_fault_info
    end

    # - - - - - - - - - - - - - - - - -

    test 'CB2', %w( green traffic-light ) do
      rag = "lambda{|so,se,st| :green }"
      bash_stub_capture(docker_run_command) { [rag, '', 0] }

      traffic_light_colour(stdout:Test::Data::PythonPytest::STDOUT_GREEN)
      assert_green
      assert_no_fault_info
    end

    # - - - - - - - - - - - - - - - - -

    test 'CB3', %w( read rag-lambda message is logged once ) do
      rag = "lambda{|so,se,st| :green }"
      bash_stub_capture(docker_run_command) { [rag, '', 0] }

      assert_log_read_rag_lambda_count 0
      traffic_light_colour(stdout:Test::Data::PythonPytest::STDOUT_GREEN)
      assert_log_read_rag_lambda_count 1
      traffic_light_colour(stdout:Test::Data::PythonPytest::STDOUT_RED)
      assert_log_read_rag_lambda_count 1
    end

    # - - - - - - - - - - - - - - - - -

    test 'xJ5', %w( lambdas are cached ) do
      rag = "lambda{|so,se,st| :green }"
      bash_stub_capture(docker_run_command) { [rag, '', 0] }

      image_name = python_pytest_image_name
      f1 = traffic_light.send('[]', image_name)
      f2 = traffic_light.send('[]', image_name)
      assert_equal f1.object_id, f2.object_id, :caching
    end

    # - - - - - - - - - - - - - - - - -

    test 'xJ7', %w( lambda status argument is an integer in a string ) do
      rag = "lambda{|so,se,st| :red }"
      bash_stub_capture(docker_run_command) { [rag, '', 0] }

      traffic_light_colour(status:'0')
      assert_red
      assert_no_fault_info
    end

    # - - - - - - - - - - - - - - - - -

    test 'xJ8', %w(
    rag-lambda can return a string or a symbol (Postel's Law) ) do
      rag = "lambda{|so,se,st| 'red' }"
      bash_stub_capture(docker_run_command) { [rag, '', 0] }
      traffic_light_colour
      assert_red
      assert_no_fault_info

      rag = "lambda{|so,se,st| :red }"
      bash_stub_capture(docker_run_command) { [rag, '', 0] }
      traffic_light_colour
      assert_red
      assert_no_fault_info
    end

    # - - - - - - - - - - - - - - - - -
    # faulty

    test 'CB4', %w(
    image_name with missing rag-lambda file,
    always gives colour==faulty,
    adds info to log
    ) do
      stderr = "cat: can't open '/usr/local/bin/red_amber_green.rb': No such file or directory"
      bash_stub_capture(docker_run_command) { ['', stderr, 1] }

      traffic_light_colour

      assert_faulty
      context = 'image_name must have /usr/local/bin/red_amber_green.rb file'
      assert_missing_lambda_logged(context)
    end

    # - - - - - - - - - - - - - - - - -

    test 'CB5', %w(
    rag-lambda which raises when eval'd,
    gives colour==faulty,
    adds message to log
    ) do
      lambda_source = 'not-a-lambda'
      bash_stub_capture(docker_run_command) { [lambda_source, '', 0] }

      traffic_light_colour

      assert_faulty
      assert_bad_lambda_logged(
        "exception when eval'ing lambda source",
        lambda_source,
        'SyntaxError',
        "/runner/code/empty_binding.rb:6: syntax error, unexpected '-'\nnot-a-lambda\n   ^\n"
      )
    end

    # - - - - - - - - - - - - - - - - -

    test 'CB6', %w(
    rag-lambda which raises when called,
    gives colour==faulty,
    adds message to log
    ) do
      lambda_source = "lambda{ |so,se,st| fail RuntimeError, '42' }"
      bash_stub_capture(docker_run_command) { [lambda_source, '', 0] }

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

    test 'CB7', %w(
    rag-lambda with too few parameters,
    gives colour==faulty,
    adds message to log
    ) do
      lambda_source = 'lambda{ |_a,_b| :red }'
      bash_stub_capture(docker_run_command) { [lambda_source, '', 0] }

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

    test 'CB8', %w(
    rag-lambda with too many parameters,
    gives colour==faulty,
    adds message to log
    ) do
      lambda_source = 'lambda{ |_a,_b,_c,_d| :red }'
      bash_stub_capture(docker_run_command) { [lambda_source, '', 0] }

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

    test 'CB9', %w(
    rag-lambda which returns non red/amber/green,
    gives colour==faulty,
    adds message to log
    ) do
      lambda_source = [
        'lambda {|so,se,st|',
        '  :orange',
        '}'
      ].join("\n")
      bash_stub_capture(docker_run_command) { [lambda_source, '', 0] }

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
      @outcome,@fault_info = *traffic_light.colour(@image_name, @stdout, @stderr, @status)
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
      message = "Read red-amber-green lambda for #{python_pytest_image_name}"
      lines.count { |line| line.include?(message) }
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    def docker_run_command
      [ 'docker run --rm --entrypoint=cat',
        python_pytest_image_name,
        RAG_LAMBDA_FILENAME
      ].join(' ')
    end

    RAG_LAMBDA_FILENAME = '/usr/local/bin/red_amber_green.rb'

    def bash_stub_capture(command, &block)
      stdout,stderr,status = *block.call
      context.sheller.capture(command, &block)
      @command = command
      @command_stdout = stdout
      @command_stderr = stderr
      @command_status = status
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    def assert_missing_lambda_logged(context)
      assert_call_info_logged(
        context:context,
        command:@command,
        stdout:@command_stdout.lines,
        stderr:@command_stderr.lines,
        status:@command_status
      )
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    def assert_bad_lambda_logged(context, lambda_source, klass, message)
      assert_call_info_logged(
        context:context,
        lambda_source:lambda_source.lines,
        class:klass,
        message:message.lines
      )
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    def assert_illegal_colour_logged(context, illegal_colour, lambda_source)
      assert_call_info_logged(
        context:context,
        illegal_colour:illegal_colour,
        lambda_source:lambda_source.lines
      )
    end

    # - - - - - - - - - - - - - - - - - - - - - -

    def assert_call_info_logged(properties)
      assert_logged_fault_info({
        call:'TrafficLight.colour(image_name,stdout,stderr,status)',
        args:{
          image_name:@image_name,
          stdout:@stdout.lines,
          stderr:@stderr.lines,
          status:@status
        },
        exception:properties
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
end
