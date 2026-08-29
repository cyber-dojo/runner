class NodeImagesSpy
  # as passed to set_context(images:), recording whether the images were
  # consulted at all.
  #
  # Answers :pulling, which is what stops a run that did not validate its
  # image_name at runner.rb's gate rather than letting it reach the daemon
  # with a name no image could have.

  def initialize
    @called = false
  end

  def pull(id:, image_name:)
    @called = true
    :pulling
  end

  def called?
    @called
  end
end
