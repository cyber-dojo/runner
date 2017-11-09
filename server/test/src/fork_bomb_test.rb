require_relative 'test_base'

class ForkBombTest < TestBase

  def self.hex_prefix
    '35758'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD5',
  %w( [Alpine] fork-bomb does not run indefinitely ) do
    in_kata_as(salmon) {
      begin
        run_cyber_dojo_sh({
          changed_files: { 'hiker.c' => fork_bomb_definition }
        })
        assert_printed 'All tests passed'
        assert_printed 'fork()'
      rescue ArgumentError
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD6',
  %w( [Ubuntu] fork-bomb does not run indefinitely ) do
    in_kata_as(salmon) {
      begin
        run_cyber_dojo_sh({
          changed_files: { 'hiker.cpp' => fork_bomb_definition }
        })
        assert_printed 'All tests passed'
        assert_printed 'fork()'
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
        assert_printed 'bomb'
        assert_printed "can't fork"
      rescue
        ArgumentError
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
        assert_printed 'bomb'
        assert_printed "Cannot fork"
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

  def assert_printed(text)
    tally = 0
    (stdout+stderr).split("\n").each { |line|
      if line.include?(text)
        tally += 1
      end
    }
    assert tally > 0, "#{text}:#{quad}"
  end


end
