# frozen_string_literal: true

class TrafficLightStub

  def initialize(colour = 'red')
    @stubbed = colour
  end

  def colour(_image_name, _stdout, _stderr, _status)
    @stubbed
  end

  @@red   = TrafficLightStub.new('red')
  @@amber = TrafficLightStub.new('amber')
  @@green = TrafficLightStub.new('green')

  def self.red  ; @@red  ; end
  def self.amber; @@amber; end
  def self.green; @@green; end

end
