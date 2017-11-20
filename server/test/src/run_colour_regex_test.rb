require_relative 'test_base'

class RunColourRegexTest < TestBase

  def self.hex_prefix
    'F6D43'
  end

  def hex_teardown
    assert @shell.fired?
  end

  # - - - - - - - - - - - - - - - - -

  test '5A2',
  %w( (cat'ing lambda from file) exception becomes amber ) do
    @shell = ShellRaiser.new(shell)
    in_kata_as(salmon) {
      run_cyber_dojo_sh
      assert_becomes_amber
       # would like to check log but there is shell-log over-coupling
    }
  end

  # - - - - - - - - - - - - - - - - -

  test '5A3',
  %w( (rag_lambda syntax-error) exception becomes amber ) do
    rag = 'sdfsdfsdf'
    @shell = ShellCatRagFileStub.new(shell, rag)
    in_kata_as(salmon) {
      run_cyber_dojo_sh
      assert_becomes_amber
    }
  end

  test '5A4',
  %w( (arg_lambda explicit raise) becomes amber ) do
    rag = 'lambda { |stdout, stderr, status| raise ArgumentError.new }'
    @shell = ShellCatRagFileStub.new(shell, rag)
    in_kata_as(salmon) {
      run_cyber_dojo_sh
      assert_becomes_amber
    }
  end

  test '5A5',
  %w( (rag_lambda returning non red/amber/green) becomes amber ) do
    rag = 'lambda { |stdout, stderr, status| return :orange }'
    @shell = ShellCatRagFileStub.new(shell, rag)
    in_kata_as(salmon) {
      run_cyber_dojo_sh
      assert_becomes_amber
    }
  end

  # - - - - - - - - - - - - - - - - -

  class ShellRaiser
    def initialize(adaptee)
      @adaptee = adaptee
      @fired = false
    end
    def fired?
      @fired
    end
    def assert(command)
      if command.end_with? "cat /usr/local/bin/red_amber_green.rb'"
        @fired = true
        raise ArgumentError.new
      else
        @adaptee.assert(command)
      end
    end
  end

  # - - - - - - - - - - - - - - - - -

  class ShellCatRagFileStub
    def initialize(adaptee, content)
      @adaptee = adaptee
      @content = content
      @fired = false
    end
    def fired?
      @fired
    end
    def assert(command)
      if command.end_with? "cat /usr/local/bin/red_amber_green.rb'"
        @fired = true
        @content
      else
        @adaptee.assert(command)
      end
    end
  end

  # - - - - - - - - - - - - - - - - -

  def assert_becomes_amber
    assert_equal '', stdout
    assert stderr.start_with? 'Assertion failed: answer() == 42'
    assert_equal 2, status
    assert_equal 'amber', colour
  end

end
