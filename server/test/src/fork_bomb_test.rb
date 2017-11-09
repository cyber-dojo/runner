require_relative 'test_base'

class ForkBombTest < TestBase

  def self.hex_prefix
    '35758'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD5',
  %w( [Alpine] fork-bomb does not run indefinitely ) do
    @log = LoggerSpy.new(nil)
    in_kata_as(salmon) {
      begin
        run_cyber_dojo_sh({
          changed_files: { 'hiker.c' => fork_bomb_definition }
        })
        # :nocov:
        assert_timed_out_or_printed 'All tests passed'
        assert_timed_out_or_printed 'fork()'
        # :nocov:
      rescue ArgumentError
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD6',
  %w( [Ubuntu] fork-bomb does not run indefinitely ) do
    @log = LoggerSpy.new(nil)
    in_kata_as(salmon) {
      begin
        run_cyber_dojo_sh({
          changed_files: { 'hiker.cpp' => fork_bomb_definition }
        })
        # :nocov:
        assert_timed_out_or_printed 'All tests passed'
        assert_timed_out_or_printed 'fork()'
        # :nocov:
      rescue ArgumentError
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def fork_bomb_definition
    [ '#include <stdio.h>',
      '#include <unistd.h>',
      '',
      'int answer(void)',
      '{',
      '    for(;;)',
      '    {',
      '        int pid = fork();',
      '        fprintf(stdout, "fork() => %d\n", pid);',
      '        fflush(stdout);',
      '        if (pid == -1)',
      '            break;',
      '    }',
      '    return 6 * 7;',
      '}'
    ].join("\n")
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4DE',
  %w( [Alpine] shell fork-bomb does not run indefinitely ) do
    @log = LoggerSpy.new(nil)
    in_kata_as(salmon) {
      begin
        run_shell_fork_bomb
        # :nocov:
        assert_timed_out_or_printed 'bomb'
        assert_timed_out_or_printed "can't fork"
        # :nocov:
      rescue ArgumentError
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4DF',
  %w( [Ubuntu] shell fork-bomb does not run indefinitely ) do
    @log = LoggerSpy.new(nil)
    in_kata_as(salmon) {
      begin
        run_shell_fork_bomb
        # :nocov:
        assert_timed_out_or_printed 'bomb'
        assert_timed_out_or_printed "Cannot fork"
        # :nocov:
      rescue ArgumentError
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def run_shell_fork_bomb
    shell_fork_bomb = 'bomb() { echo "bomb"; bomb | bomb & }; bomb'
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => shell_fork_bomb }
    })
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_timed_out_or_printed(text)
    tally = 0
    (stdout+stderr).split("\n").each { |line|
      if line.include?(text)
        tally += 1
      end
    }
    assert (colour == 'timed_out') || (tally > 0), "#{colour}:#{text}:#{quad}"
  end


end
