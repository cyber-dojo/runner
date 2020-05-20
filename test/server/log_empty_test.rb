# frozen_string_literal: true
require_relative 'test_base'
require_relative 'process_decorator'

class LogEmptyTest < TestBase

  def self.id58_prefix
    '6f2'
  end

  # - - - - - - - - - - - - - - - - -

  test 'dFA', %w(
  log_empty? helper method ignores known circleci warning
  ) do
    decorated = externals.process
    on_ci = self.on_ci?
    warning = TestBase::KNOWN_CIRCLE_CI_WARNING

    spawn = lambda {|command,options|
      pid = decorated.spawn(command,options)
      unless on_ci
        options[:err].write(warning)
      end
      pid
    }

    externals.instance_exec {
      @process = ProcessDecorator.new(decorated,{spawn:spawn})
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
      externals.instance_exec { @process = decorated }
    end
  end

end
