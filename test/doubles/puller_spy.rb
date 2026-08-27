class PullerSpy
  # as passed to set_context(puller:), recording whether the puller was
  # consulted at all.
  #
  # Answers :pulling, which is what stops a run that did not validate its
  # image_name at runner.rb's pulling gate rather than letting it reach the
  # daemon with a name no image could have.

  def initialize
    @called = false
  end

  def pull_image(id:, image_name:)
    @called = true
    :pulling
  end

  def called?
    @called
  end
end
