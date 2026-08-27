class DaemonOneRequestStub
  # as passed to set_context(daemon:), for the calls that make exactly one
  # request and read one answer, eg Node#image_names and Puller's pull.
  # Answers the given [code,body] and remembers what it was asked, so a test
  # can pin the endpoint as well as what came back from it.

  def initialize(response)
    @response = response
    @call = nil
  end

  attr_reader :call

  def request(method, path, body = nil)
    @call = [method, path, body]
    @response
  end
end
