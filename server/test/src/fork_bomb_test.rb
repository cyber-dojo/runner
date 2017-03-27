require_relative 'test_base'
require_relative 'os_helper'

class ForkBombTest < TestBase

  include OsHelper

  def self.hex_prefix; '35758'; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD5', %w( [Alpine]
  fork-bomb in C fails to go off
  ) do
    gcc_assert_files['hiker.c'] =
    [
      '#include "hiker.h"',
      '#include <stdio.h>',
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
    sss_run({ visible_files:gcc_assert_files })
    assert_status success
    assert_stderr ''
    lines = stdout.split("\n")
    assert lines.count{ |line| line == 'All tests passed' } > 42
    assert lines.count{ |line| line == 'fork() => 0' } > 42
    assert lines.count{ |line| line == 'fork() => -1' } > 42
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4DE', %w( [Alpine]
  fork-bomb in shell fails to go off
  ) do
    cyber_dojo_sh = 'bomb() { bomb | bomb & }; bomb'
    sss_run({ visible_files:{'cyber-dojo.sh' => cyber_dojo_sh }})
    assert_status success
    assert_stdout ''
    assert_stderr_include "./cyber-dojo.sh: line 1: can't fork"
  end

end
