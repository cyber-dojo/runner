require_relative 'test_base'

class RunCatRagTest < TestBase

  def self.hex_prefix
    'F6D43'
  end

  def hex_setup
    @true_shell = shell
  end

  def hex_teardown
    assert @shell.fired?
  end

  # - - - - - - - - - - - - - - - - -

  test 'EAA',
  %w( cat lambda file exception becomes nil ) do
    @shell = ShellRaiser.new(shell)
    in_kata_as(salmon) {
      run_cyber_dojo_sh
    }
    assert_nil rag, quint
  end

  # - - - - - - - - - - - - - - - - -

  test 'EAB',
  %w( cat lambda content becomes content ) do
    assert_cat_rag('')
    assert_cat_rag('sdfsdfsdf')
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

  def assert_cat_rag(content)
    @shell = ShellCatRagFileStub.new(@true_shell, content)
    in_kata_as(salmon) {
      run_cyber_dojo_sh
    }
    assert_equal content, rag, quint
  end

end
