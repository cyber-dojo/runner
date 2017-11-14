require_relative 'test_base'

class ColourRegexTest < TestBase

  def self.hex_prefix
    'F6D43'
  end

  # - - - - - - - - - - - - - - - - -

  class CustomRaisingShell
    def initialize(adaptee)
      @adaptee = adaptee
      @fired = false
    end
    def fired?
      @fired
    end
    def assert_exec(command)
      if command.end_with? "cat /usr/local/bin/red_amber_green.rb'"
        @fired = true
        fail ArgumentError.new
      else
        @adaptee.assert_exec(command)
      end
    end
  end

  test 'EAA',
  %w( exception raised when extracting lambda is trapped and becomes amber ) do
    @shell = CustomRaisingShell.new(shell)
    in_kata_as(salmon) {
      run_cyber_dojo_sh
      assert @shell.fired?
      assert_red_becomes_amber
       # would like to check log but there is shell-log over-coupling
    }
  end

  # - - - - - - - - - - - - - - - - -

  class CustomRagLambdaShell
    def initialize(adaptee, rag_code)
      @adaptee = adaptee
      @rag_code = rag_code
      @fired = false
    end
    def fired?
      @fired
    end
    def assert_exec(command)
      if command.end_with? "cat /usr/local/bin/red_amber_green.rb'"
        @fired = true
        [ @rag_code, '' ]
      else
        @adaptee.assert_exec(command)
      end
    end
  end

  test 'EAB',
  %w( exception raised when lambda syntax-error is trapped and becomes amber ) do
    code = 'sdfsdfsdf'
    @shell = CustomRagLambdaShell.new(shell, code)
    in_kata_as(salmon) {
      run_cyber_dojo_sh
      assert @shell.fired?
      assert_red_becomes_amber
    }
  end

  test 'EAC',
  %w( exception raised when lambda raises is trapped and becomes amber ) do
    code = 'lambda { |stdout, stderr, status| fail ArgumentError.new }'
    @shell = CustomRagLambdaShell.new(shell, code)
    in_kata_as(salmon) {
      run_cyber_dojo_sh
      assert @shell.fired?
      assert_red_becomes_amber
    }
  end

  test 'EAD',
  %w( when lambda returns non red/amber/green its trapped and becomes amber ) do
    code = 'lambda { |stdout, stderr, status| return :orange }'
    @shell = CustomRagLambdaShell.new(shell, code)
    in_kata_as(salmon) {
      run_cyber_dojo_sh
      assert @shell.fired?
      assert_red_becomes_amber
    }
  end

  # - - - - - - - - - - - - - - - - -

  def assert_red_becomes_amber
    assert_equal '', stdout
    assert stderr.start_with? 'Assertion failed: answer() == 42'
    assert_equal 2, status
    assert_equal 'amber', colour
  end

end
