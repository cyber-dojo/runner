require_relative 'test_base'

class ForkBombTest < TestBase

  def self.hex_prefix
    '35758'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # fork-bombs from the source
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD5',
  %w( [Alpine] fork-bomb does not run indefinitely ) do
    content = '#include "hiker.h"' + "\n" + fork_bomb_definition
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: { 'hiker.c' => content },
          max_seconds: 5
      })
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD6',
  %w( [Ubuntu] fork-bomb does not run indefinitely ) do
    content = '#include "hiker.hpp"' + "\n" + fork_bomb_definition
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: { 'hiker.cpp' => content },
          max_seconds: 5
      })
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
  # fork-bombs from the shell
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4DE',
  %w( [Alpine] fork-bomb in shell does not run indefinitely ) do
    @log = LoggerSpy.new(nil)
    in_kata_as(salmon) {
      begin
        run_shell_fork_bomb
      rescue ArgumentError
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4DF',
  %w( [Ubuntu] fork-bomb in shell does not run indefinitely ) do
    @log = LoggerSpy.new(nil)
    in_kata_as(salmon) {
      begin
        run_shell_fork_bomb
      rescue ArgumentError
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def run_shell_fork_bomb
    shell_fork_bomb = 'bomb() { bomb | bomb & }; bomb'
    run_cyber_dojo_sh({
      changed_files: {'cyber-dojo.sh' => shell_fork_bomb },
        max_seconds: 5
    })
  end

end
