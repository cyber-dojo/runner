require_relative 'test_base'

class RunColourRegexTest < TestBase

  def self.hex_prefix
    'F6D43'
  end

  def hex_teardown
    if @shell.respond_to? :fired?
      assert @shell.fired?
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '5A2',
  %w( (cat'ing lambda from file) exception becomes amber ) do
    @shell = ShellRaiser.new(shell)
    in_kata_as('salmon') {
      run_cyber_dojo_sh
      assert_colour 'amber'
      # would like to check log but there is shell-log over-coupling
    }
  end

  # - - - - - - - - - - - - - - - - -

  test '5A3',
  %w( (rag_lambda syntax-error) exception becomes amber ) do
    assert_rag(
      <<~RUBY
      sdfsdfsdf
      RUBY
    )
  end

  test '5A4',
  %w( (rag_lambda explicit raise) becomes amber ) do
    assert_rag(
      <<~RUBY
      lambda { |stdout, stderr, status|
        raise ArgumentError.new
      }
      RUBY
    )
  end

  test '5A5',
  %w( (rag_lambda returning non red/amber/green) becomes amber ) do
    assert_rag(
      <<~RUBY
      lambda { |stdout, stderr, status|
        return :orange
      }
      RUBY
    )
  end

  test '5A6',
  %w( (rag_lambda with too few parameters) becomes amber ) do
    assert_rag(
      <<~RUBY
      lambda { |stdout, stderr|
        return :red
      }
      RUBY
    )
  end

  test '5A7',
  %w( (rag_lambda with too many parameters) becomes amber ) do
    assert_rag(
      <<~RUBY
      lambda { |stdout, stderr, status, extra|
        return :red
      }
      RUBY
    )
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '6A1',
  %w( red/amber/green progression test ) do
    filename = (os == :Alpine) ? 'hiker.c' : 'hiker.cpp'
    src = starting_files[filename]
    in_kata_as('salmon') {
      run_cyber_dojo_sh
      assert_colour 'red'
      run_cyber_dojo_sh( {
        changed_files:{ filename => src.sub('6 * 9', '6 * 7') }
      })
      assert_colour 'green'
      run_cyber_dojo_sh( {
        changed_files:{ filename => src.sub('6 * 9', '6 * 9sdsd') }
      })
      assert_colour 'amber'
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

  def assert_rag(lambda)
    @shell = ShellCatRagFileStub.new(shell, lambda)
    in_kata_as('salmon') {
      run_cyber_dojo_sh
      assert_colour 'amber'
    }
  end

end
