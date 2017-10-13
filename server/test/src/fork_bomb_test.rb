require_relative 'test_base'
require_relative 'os_helper'

class ForkBombTest < TestBase

  include OsHelper

  def self.hex_prefix
    '35758'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # fork-bombs from the source
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD5',
  %w( [Alpine] fork-bomb in C fails to go off ) do
    gcc_assert_files['hiker.c'] =
      '#include "hiker.h"' + "\n" + fork_bomb_definition
    sss_run({ visible_files:gcc_assert_files })
    assert_status success
    assert_stderr ''
    lines = stdout.split("\n")
    assert lines.count{ |line| line == 'All tests passed' } > 42
    assert lines.count{ |line| line == 'fork() => 0' } > 42
    assert lines.count{ |line| line == 'fork() => -1' } > 42
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD6',
  %w( [Ubuntu] fork-bomb in C++ fails to go off ) do
    clangpp_assert_files['hiker.cpp'] =
      '#include "hiker.hpp"' + "\n" + fork_bomb_definition
    sss_run({ visible_files:clangpp_assert_files })
    # It fails in a non-deterministic way.
    assert status == 2 || status == 'timed_out'
    lines = stdout.split("\n")
    assert stdout == '' || lines.count{ |line| line == 'fork() => 0' } > 42
    assert stdout == '' || lines.count{ |line| line == 'fork() => -1' } > 42
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
  %w( [Alpine] fork-bomb in shell fails to go off ) do
    # A shell fork-bomb fails in a non-deterministic way.
    # Sometimes, it throws an ArgumentError exception.
    # The nocov markers keep coverage at 100%
    @log = LoggerSpy.new(nil)
    begin
      sss_run_shell_fork_bomb
    # :nocov:
      assert_status success
      assert_stdout ''
      assert_stderr_include "./cyber-dojo.sh: line 1: can't fork"
    rescue ArgumentError
      rag_filename = '/usr/local/bin/red_amber_green.rb'
      cmd = "'cat #{rag_filename}'"
      assert /COMMAND:docker .* sh -c #{cmd}/.match @log.spied[1]
      assert_equal 'STATUS:2',                      @log.spied[2]
      assert_equal 'STDOUT:',                       @log.spied[3]
      assert_equal "STDERR:sh: can't fork\n",       @log.spied[4]
    # :nocov:
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4DF',
  %w( [Ubuntu] fork-bomb in shell fails to go off ) do
    # A shell fork-bomb fails in a non-deterministic way.
    # Sometimes, it throws an ArgumentError exception.
    # The nocov markers keep coverage at 100%
    @log = LoggerSpy.new(nil)
    begin
      sss_run_shell_fork_bomb
    # :nocov:
      assert_status success
      assert_stdout ''
      assert_stderr_include "./cyber-dojo.sh: Cannot fork"
    rescue ArgumentError
      rag_filename = '/usr/local/bin/red_amber_green.rb'
      cmd = "'cat #{rag_filename}'"
      assert /COMMAND:docker .* sh -c #{cmd}/.match @log.spied[1]
      assert_equal 'STATUS:2',                      @log.spied[2]
      assert_equal 'STDOUT:',                       @log.spied[3]
      assert_equal "STDERR:sh: 1: Cannot fork\n",   @log.spied[4]
    # :nocov:
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def sss_run_shell_fork_bomb
    cyber_dojo_sh = 'bomb() { bomb | bomb & }; bomb'
    sss_run({ visible_files:{'cyber-dojo.sh' => cyber_dojo_sh }})
  end

end
