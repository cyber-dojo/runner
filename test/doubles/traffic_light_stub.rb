# frozen_string_literal: true

class TrafficLightStub

  def initialize(colour = 'red')
    @stubbed = colour
  end

  @@red   = TrafficLightStub.new('red')
  @@amber = TrafficLightStub.new('amber')
  @@green = TrafficLightStub.new('green')

  def self.red  ; @@red  ; end
  def self.amber; @@amber; end
  def self.green; @@green; end

end
