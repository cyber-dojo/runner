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
  'lambda is retrieved from image only once' do
    cater = BashStubRagFileCatter.new(amber_lambda)
    @external = External.new({ 'bash' => cater })
    5.times {
      assert_equal 'amber', traffic_light.colour('','',0,image_name)
    }
    assert cater.fired_once?
  end

  # - - - - - - - - - - - - - - - -

  def amber_lambda
    <<~RUBY
    lambda { |stdout, stderr, status|
      :amber
    }
    RUBY
  end

end
