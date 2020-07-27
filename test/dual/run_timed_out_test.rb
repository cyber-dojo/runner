# frozen_string_literal: true
require_relative '../test_base'

module Dual
  class RunTimedOutTest < TestBase

    def self.id58_prefix
      'c7A'
    end

    # - - - - - - - - - - - - - - - - - - - - -

    c_assert_test 'g55', %w( timeout ) do
      on_client {
        # :nocov_server:
        set_context
        # :nocov_server:
      }
      on_server {
        # :nocov_client:
        stdout_tgz = TGZ.of({'stderr' => 'any'})
        set_context(
           logger:StdoutLoggerSpy.new,
            piper:piper=PiperStub.new(stdout_tgz),
          process:process=ProcessSpawnerStub.new
        )
        puller.add(image_name)
        process.spawn { 42 }
        process.detach { ThreadTimedOutStub.new }
        process.kill {}
        # :nocov_client:
      }

      hiker_c = starting_files['hiker.c']
      from = 'return 6 * 9'
      to = "    for (;;);\n    return 6 * 7;"
      run_cyber_dojo_sh({
        changed: { 'hiker.c' => hiker_c.sub(from, to) },
        max_seconds: 3
      })

      assert timed_out?, run_result
    end

    private

    # :nocov_client:
    class ThreadTimedOutStub
      def initialize
        @n = 0
      end
      def value
        # capture3_with_timeout calls thread.value (to get status) twice
        @n += 1
        if @n === 1
          # 1st call is in last statement of Timeout block
          raise Timeout::Error
        end
        if @n === 2
          # 2nd call is in first statement in ensure block
          137
        end
      end
      def join(_seconds)
        nil
      end
    end
    # :nocov_client:

  end
end
