# frozen_string_literal: true
require_relative 'requester'
require_relative 'responder'

module HttpJson

  def self.service(http, hostname, port, exception_class)
    requester = Requester.new(http, hostname, port)
    Responder.new(requester, exception_class)
  end

end
