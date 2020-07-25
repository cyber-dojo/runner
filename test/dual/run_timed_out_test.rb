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
        @context = Context.new(
          logger:StdoutLoggerSpy.new,
          process:process=ProcessSpawnerStub.new
        )
        puller.add(image_name)
        process.spawn { raise Timeout::Error }
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

  end
end
