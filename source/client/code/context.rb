# frozen_string_literal: true
require_relative 'externals/languages_start_points_http_proxy'
require_relative 'externals/runner_http_proxy'
require_relative 'prober'

class Context

  def initialize
    @prober = Prober.new(self)
    @languages_start_points = LanguagesStartPointsHttpProxy.new
    @runner = RunnerHttpProxy.new
  end

  attr_reader :prober, :languages_start_points, :runner

end
