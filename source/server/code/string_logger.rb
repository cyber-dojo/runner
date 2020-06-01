# frozen_string_literal: true

class StringLogger

  def initialize
    @log = ''
  end

  attr_reader :log

  def write(message)
    return if message.empty?
    return if special_case(message)
    message += "\n" if message[-1] != "\n"
    @log += message
  end

  private

  def special_case(message)
    on_ci? && known_circleci_warning?(message)
  end

  def on_ci?
    ENV['CIRCLECI'] === 'true'
  end

  def known_circleci_warning?(message)
    message === KNOWN_CIRCLE_CI_WARNING
  end

  KNOWN_CIRCLE_CI_WARNING =
    'WARNING: Your kernel does not support swap limit capabilities ' +
    'or the cgroup is not mounted. ' +
    "Memory limited without swap.\n"

end
