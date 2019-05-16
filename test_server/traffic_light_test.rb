require_relative 'test_base'

class TrafficLightTest < TestBase

  def self.hex_prefix
    '332'
  end

  def traffic_light
    external.traffic_light
  end

  # - - - - - - - - - - - - - - - -

  test '6CC',
  'block is used to populate the cache once only' do
    @count = 0
    5.times {
      ragger = traffic_light.rag_lambda('gcc_assert') { @count += 1; eval(purple) }
      assert_equal :purple, ragger.call('stdout','stderr',status=23)
    }
    assert_equal 1, @count
  end

  # - - - - - - - - - - - - - - - -

  def purple
    <<~RUBY
    lambda { |stdout, stderr, status|
      return :purple
    }
    RUBY
  end

end
