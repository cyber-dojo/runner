# frozen_string_literal: true
class Prober
  def initialize(context)
    @context = context
  end

  def alive?
    true
  end

  def ready?
    [languages_start_points, runner].all?(&:ready?)
  end

  def sha
    ENV.fetch('SHA', nil)
  end

  private

  def languages_start_points
    @context.languages_start_points
  end

  def runner
    @context.runner
  end
end
