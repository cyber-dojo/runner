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
            piper:PiperStub.new(stdout_tgz),
          process:process=ProcessSpawnerStub.new
        )
        puller.add(image_name)
        process.spawn { 42 }
        process.detach { ThreadTimedOutStub.new }
        process.kill { nil }
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
        @stubs = {
          1 => lambda { raise Timeout::Error },
          2 => lambda { 137 }
        }
      end
      def value
        @n += 1
        @stubs[@n].call
      end
      def join(_seconds)
        nil
      end
    end
    # :nocov_client:

  end
end
