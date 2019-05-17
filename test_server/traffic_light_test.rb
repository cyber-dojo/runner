require_relative 'test_base'
require_relative 'bash_stub_rag_raiser'
require_relative 'bash_stub_rag_file_catter'

class TrafficLightTest < TestBase

  def self.hex_prefix
    '332'
  end

  def traffic_light
    external.traffic_light
  end

  def hex_teardown
    stub = external.bash
    if stub.respond_to?(:fired_once?)
      assert stub.fired_once?
    end
  end

  # - - - - - - - - - - - - - - - -

  test '6A1',
  %w( [C,assert] red/amber/green progression test ) do
    filename = 'hiker.c'
    src = starting_files[filename]['content']
    run_cyber_dojo_sh
    assert_colour 'red'

    run_cyber_dojo_sh( {
      changed:{
        filename => intact(src.sub('6 * 9', '6 * 7'))
      }
    })
    assert_colour 'green'

    run_cyber_dojo_sh( {
      changed:{
        filename => intact(src.sub('6 * 9', '6 * 9sdsd'))
      }
    })
    assert_colour 'amber'
  end

  # - - - - - - - - - - - - - - - -

  test '6CC',
  'lambda is retrieved from image only once' do
    cater = BashStubRagFileCatter.new(amber_lambda)
    @external = External.new({ 'bash' => cater })
    5.times {
      assert_equal 'amber', traffic_light.colour('','',0,image_name)
    }
  end

  # - - - - - - - - - - - - - - - - -

  test '5A2',
  %w( exception when (catting lambda from file) becomes amber ) do
    raiser = BashStubRagRaiser.new('fubar')
    @external = External.new({ 'bash' => raiser })
    with_captured_log {
      run_cyber_dojo_sh
    }
    assert_colour 'amber'
    assert_rag_log 'fubar'
  end

  # - - - - - - - - - - - - - - - - -

  test '5A3',
  %w( (rag_lambda syntax-error) exception becomes amber ) do
    assert_amber("undefined local variable or method `sdf'",
      <<~RUBY
      sdf
      RUBY
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '5A4',
  %w( (rag_lambda explicit raise) becomes amber ) do
    assert_amber('wibble',
      <<~RUBY
      lambda { |stdout, stderr, status|
        raise ArgumentError.new('wibble')
      }
      RUBY
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '5A5',
  %w( (rag_lambda returning non red/amber/green) becomes amber ) do
    assert_amber('orange',
      <<~RUBY
      lambda { |stdout, stderr, status|
        return :orange
      }
      RUBY
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '5A6',
  %w( (rag_lambda with too few parameters) becomes amber ) do
    assert_amber('wrong number of arguments (given 3, expected 2)',
      <<~RUBY
      lambda { |stdout, stderr|
        return :red
      }
      RUBY
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '5A7',
  %w( (rag_lambda with too many parameters) becomes amber ) do
    assert_amber('wrong number of arguments (given 3, expected 4)',
      <<~RUBY
      lambda { |stdout, stderr, status, extra|
        return :red
      }
      RUBY
    )
  end

  private

  def assert_amber(expected_log, lambda)
    cater = BashStubRagFileCatter.new(lambda)
    @external = External.new({ 'bash' => cater })
    with_captured_log {
      run_cyber_dojo_sh
    }
    assert_rag_log expected_log
    assert_colour 'amber'
  end

  # - - - - - - - - - - - - - - - - -

  def assert_rag_log(msg)
    expected = "red_amber_green lambda error mapped to :amber\n#{msg}"
    assert @log.include?(expected), @log
  end

  # - - - - - - - - - - - - - - - - -

  def amber_lambda
    <<~RUBY
    lambda { |stdout, stderr, status|
      :amber
    }
    RUBY
  end

end
