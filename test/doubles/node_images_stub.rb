class NodeImagesStub
  # as passed to set_context(images:), answering one verdict to every pull, so
  # that a test can say whether the image is on the node without having to put
  # it there.

  def initialize(answering:)
    @answering = answering
  end

  def pull(id:, image_name:)
    @answering
  end
end
