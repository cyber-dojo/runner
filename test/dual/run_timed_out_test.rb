# frozen_string_literal: true
require_relative '../test_base'

module Dual
  class RunTimedOutTest < TestBase

    def self.id58_prefix
      'c7A'
    end

    # - - - - - - - - - - - - - - - - - - - - -

    c_assert_test 'g55', %w( timeout ) do
      if on_server?
        set_context(
          logger:StdoutLoggerSpy.new,
          process:process=ProcessSpawnerStub.new
        )
        puller.add(image_name)
        tp = ProcessSpawner.new
        process.spawn { |_cmd,opts| tp.spawn('sleep 10', opts) }
        process.detach { |pid| tp.detach(pid); ThreadTimedOutStub.new }
        process.kill { |signal,pid| tp.kill(signal, pid) }
      end

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

    class ThreadTimedOutStub
      def initialize
        @n = 0
      end
      def value
        @n += 1
        if @n === 1
          raise Timeout::Error
        end
        if @n === 2
          0
        end
      end
      def join(_seconds)
        nil
      end
    end

  end
end
