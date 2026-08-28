class SparePoolSpy
  # as passed to set_context(spares:), recording which images it was asked to
  # warm, and holding no spare so that a claim is always a miss.

  def initialize
    @warmed = []
  end

  attr_reader :warmed

  def warm(image_name:)
    @warmed << image_name
  end

  def claim(image_name:)
    nil
  end
end
