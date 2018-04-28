require_relative 'test_base'
require_relative 'bash_stub_raiser'
require_relative 'bash_stub_rag_file_catter'

class RunColourRegexTest < TestBase

  def self.hex_prefix
    'F6D43'
  end

  def hex_teardown
    if external.bash.respond_to? :fired?
      assert external.bash.fired?
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '6A1',
  %w( [C,assert] red/amber/green progression test ) do
    filename = 'hiker.c'
    src = starting_files[filename]
    in_kata_as('salmon') {
      run_cyber_dojo_sh
      assert_colour 'red'
      run_cyber_dojo_sh( {
        changed_files:{
          filename => src.sub('6 * 9', '6 * 7')
        }
      })
      assert_colour 'green'
      run_cyber_dojo_sh( {
        changed_files:{
          filename => src.sub('6 * 9', '6 * 9sdsd')
        }
      })
      assert_colour 'amber'
    }
  end

  # - - - - - - - - - - - - - - - - -

  test '5A2',
  %w( (cat'ing lambda from file) exception becomes amber ) do
    raiser = BashStubRaiser.new('fubar')
    @external = External.new({ 'bash' => raiser })
    in_kata_as('salmon') {
      run_cyber_dojo_sh
      assert_colour 'amber'
    }
  end

  # - - - - - - - - - - - - - - - - -

  test '5A3',
  %w( (rag_lambda syntax-error) exception becomes amber ) do
    assert_rag("undefined local variable or method `sdf'",
      <<~RUBY
      sdf
      RUBY
    )
  end

  test '5A4',
  %w( (rag_lambda explicit raise) becomes amber ) do
    assert_rag('wibble',
      <<~RUBY
      lambda { |stdout, stderr, status|
        raise ArgumentError.new('wibble')
      }
      RUBY
    )
  end

  test '5A5',
  %w( (rag_lambda returning non red/amber/green) becomes amber ) do
    assert_rag('must return one of [:red,:amber,:green]',
      <<~RUBY
      lambda { |stdout, stderr, status|
        return :orange
      }
      RUBY
    )
  end

  test '5A6',
  %w( (rag_lambda with too few parameters) becomes amber ) do
    assert_rag('wrong number of arguments (given 3, expected 2)',
      <<~RUBY
      lambda { |stdout, stderr|
        return :red
      }
      RUBY
    )
  end

  test '5A7',
  %w( (rag_lambda with too many parameters) becomes amber ) do
    assert_rag('wrong number of arguments (given 3, expected 4)',
      <<~RUBY
      lambda { |stdout, stderr, status, extra|
        return :red
      }
      RUBY
    )
  end

  # - - - - - - - - - - - - - - - - -

  def assert_rag(_expected, lambda)
    cater = BashStubRagFileCatter.new(lambda)
    @external = External.new({ 'bash' => cater })
    in_kata_as('salmon') {
      run_cyber_dojo_sh
      assert_colour 'amber'
    }
  end

end
