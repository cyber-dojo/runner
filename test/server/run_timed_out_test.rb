require_relative '../test_base'

class RunTimedOutTest < TestBase

  test 'e7Kc20', %w(
  | outcome is timed_out when the deadline passes with the payload unfinished
  | and what the run said goes to the log
  | because there is no payload to report and the learner is owed a traffic light
  ) do
    set_context(
      logger: @logger = StdoutLoggerSpy.new,
      docker: DockerDaemonStub.new(timed_out: true)
    )
    images.add(image_name)

    run = run_cyber_dojo_sh

    assert_equal 'timed_out', run['outcome']
    assert_equal Runner::STATUS[:timed_out].to_s, run['status']
    assert_includes @logger.logged, 'timed_out'
  end
end
