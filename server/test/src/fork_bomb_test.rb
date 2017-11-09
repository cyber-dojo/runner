require_relative 'test_base'

class ForkBombTest < TestBase

  def self.hex_prefix
    '35758'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD5',
  %w( fork-bomb does not run indefinitely ) do
    fork_bomb_test
  end

  def fork_bomb_test
    @log = LoggerSpy.new(nil)
    filename = (os == :Alpine ? 'hiker.c' : 'hiker.cpp')
    in_kata_as(salmon) {
      begin
        run_cyber_dojo_sh({
          changed_files: { filename => fork_bomb_definition }
        })
        # :nocov:
        assert_timed_out_or_printed 'All tests passed'
        assert_timed_out_or_printed 'fork()'
        # :nocov:
      rescue ArgumentError
      end
    }
  end

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

  multi_os_test '4DE',
  %w( shell fork-bomb does not run indefinitely ) do
    shell_fork_bomb_test
  end

  def shell_fork_bomb_test
    @log = LoggerSpy.new(nil)
    cant_fork = (os == :Alpine ? "can't fork" : 'Cannot fork')
    in_kata_as(salmon) {
      begin
        shell_fork_bomb = 'bomb() { echo "bomb"; bomb | bomb & }; bomb'
        run_cyber_dojo_sh({
          changed_files: { 'cyber-dojo.sh' => shell_fork_bomb }
        })
        # :nocov:
        assert_timed_out_or_printed 'bomb'
        assert_timed_out_or_printed cant_fork
        # :nocov:
      rescue ArgumentError
      end
    }
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
