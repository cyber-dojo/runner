require_relative 'http_proxy/languages_start_points'
require_relative 'http_proxy/runner'
require_relative 'prober'

class Context
  def initialize(_options = {})
    @prober = Prober.new(self)
    @languages_start_points = ::HttpProxy::LanguagesStartPoints.new
    @runner = ::HttpProxy::Runner.new
  end

  attr_reader :prober, :languages_start_points, :runner
end
