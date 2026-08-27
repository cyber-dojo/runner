class DaemonSequenceStub
  # as passed to set_context(daemon:), for the calls that make more than one
  # request and care about the order. Answers each canned [code,body] in turn
  # and remembers every request, so a test can pin the sequence as well as
  # what came back from it.

  def initialize(responses)
    @responses = responses
    @calls = []
  end

  attr_reader :calls

  def request(method, path, body = nil)
    @calls << [method, path, body]
    @responses.shift
  end
end
