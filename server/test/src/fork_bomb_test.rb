require_relative 'test_base'

class ForkBombTest < TestBase

  def self.hex_prefix
    '35758'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # fork-bombs from the source
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD5',
  %w( [Alpine] fork-bomb in C fails to go off ) do
    in_kata_as(salmon) {
      content = '#include "hiker.h"' + "\n" + fork_bomb_definition
      run_cyber_dojo_sh({
        changed_files: { 'hiker.c' => content }
      })
    }
    assert_colour 'green'
    assert_stderr ''
    lines = stdout.split("\n")
    assert lines.count{ |line| line == 'All tests passed' } > 42
    assert lines.count{ |line| line == 'fork() => 0' } > 42
    assert lines.count{ |line| line == 'fork() => -1' } > 42
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD6',
  %w( [Ubuntu] fork-bomb in C++ fails to go off ) do
    in_kata_as(salmon) {
      content = '#include "hiker.hpp"' + "\n" + fork_bomb_definition
      run_cyber_dojo_sh({
        changed_files: { 'hiker.cpp' => content }
      })
    }
    # It fails in a non-deterministic way.
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
    in_kata_as(salmon) {
      begin
        run_shell_fork_bomb
      # :nocov:
        assert_colour 'amber'
        assert_stdout ''
        assert_stderr_include "./cyber-dojo.sh: line 1: can't fork"
      rescue ArgumentError
        rag_filename = '/usr/local/bin/red_amber_green.rb'
        cmd = "'cat #{rag_filename}'"
        assert /COMMAND:docker .* sh -c #{cmd}/.match @log.spied[1]
        assert_equal 'STATUS:2', @log.spied[2]
        assert_equal 'STDOUT:', @log.spied[3]
        fail1 = "STDERR:sh: can't fork"
        fail2 = 'STDERR:runtime/cgo: pthread_create failed: Resource temporarily unavailable'
        line = @log.spied[4].split("\n")[0]
        assert [ fail1, fail2 ].include?(line), line
      # :nocov:
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4DF',
  %w( [Ubuntu] fork-bomb in shell fails to go off ) do
    # A shell fork-bomb fails in a non-deterministic way.
    # Sometimes, it throws an ArgumentError exception.
    # The nocov markers keep coverage at 100%
    @log = LoggerSpy.new(nil)
    in_kata_as(salmon) {
      begin
        run_shell_fork_bomb
      # :nocov:
        assert_colour 'amber'
        assert_stdout ''
        assert_stderr_include "./cyber-dojo.sh: Cannot fork"
      rescue ArgumentError
        rag_filename = '/usr/local/bin/red_amber_green.rb'
        cmd = "'cat #{rag_filename}'"
        assert /COMMAND:docker .* sh -c #{cmd}/.match @log.spied[1]
        assert [ 'STATUS:2','STATUS:126' ].include? @log.spied[2]
        assert_equal 'STDOUT:', @log.spied[3]
        fail1 = 'STDERR:sh: 1: Cannot fork'
        fail2 = 'STDERR:runtime/cgo: pthread_create failed: Resource temporarily unavailable'
        line = @log.spied[4].split("\n")[0]
        assert [ fail1, fail2 ].include?(line), line
      # :nocov:
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def run_shell_fork_bomb
    shell_fork_bomb = 'bomb() { bomb | bomb & }; bomb'
    run_cyber_dojo_sh({
      changed_files: {'cyber-dojo.sh' => shell_fork_bomb }
    })
  end

end
