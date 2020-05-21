# frozen_string_literal: true

class TrafficLightStub

  def initialize(colour = 'red')
    @stubbed = colour
  end

  def colour(_image_name, _stdout, _stderr, _status)
    @stubbed
  end

end
