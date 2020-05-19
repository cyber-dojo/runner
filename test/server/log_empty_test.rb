# frozen_string_literal: true
require_relative 'test_base'

class LogEmptyTest < TestBase

  def self.id58_prefix
    '6f2'
  end

  # - - - - - - - - - - - - - - - - -

  class CircleCiProcessAdapter
    def initialize(process, on_ci, warning)
      @on_ci = on_ci
      @process = process
      @warning = warning
    end
    def spawn(command, options)
      pid = @process.spawn(command, options)
      unless @on_ci
        options[:err].write(@warning)
      end
      pid
    end

    def wait(pid)
      @process.wait(pid)
    end

    #def kill(signal, pid) # only called on timeout
    #def detach(pid)       # only called on timeout

  end

  # - - - - - - - - - - - - - - - - -

  test 'dFA', %w(
  log_empty? method ignores known circleci warning
  ) do
    original_process = externals.process
    on_ci = self.on_ci?
    warning = TestBase::KNOWN_CIRCLE_CI_WARNING
    externals.instance_exec {
      @process = CircleCiProcessAdapter.new(original_process, on_ci, warning)
    }

    run_cyber_dojo_sh

    assert_equal 'red', colour, pretty_result(:red)
    assert_equal warning, log, pretty_result(:log_has_circleci_warning)
    begin
      original_ENV_CIRCLECI = ENV['CIRCLECI']
      ENV['CIRCLECI'] = 'true'
      assert log_empty?, pretty_result(:circleci_warning_is_ignored_when_on_ci)
    ensure
      ENV['CIRCLECI'] = original_ENV_CIRCLECI
      externals.instance_exec {
        @process = original_process
      }
    end
  end

end
