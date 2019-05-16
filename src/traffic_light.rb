
class TrafficLight

  def initialize
    @cache = {}
  end

  def rag_lambda(image_name, &block)
    @cache[image_name] ||= block.call
  end

end
