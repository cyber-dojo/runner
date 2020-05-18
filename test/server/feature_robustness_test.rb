# frozen_string_literal: true
require_relative 'test_base'

class RobustNessTest < TestBase

  def self.id58_prefix
    '1B5'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD4',
  'cyber-dojo.sh killing its own processes is contained' do
    run_cyber_dojo_sh_kill_pid_for('init')
    run_cyber_dojo_sh_kill_pid_for('main.sh')
    run_cyber_dojo_sh_kill_pid_for('cyber-dojo.sh')
  end

  def run_cyber_dojo_sh_kill_pid_for(command)
    run_cyber_dojo_sh(
      changed: {
        'cyber-dojo.sh' => kill_pid_for(command)
      }
    )
  end

  def kill_pid_for(command)
    ps = os === :Alpine ? 'ps -a' : 'ps -ax'
    [
      "#{ps} | tail -n +2 > /tmp/ps.txt",
      "PID=$(cat /tmp/ps.txt | grep #{command} | awk '{print $1;}')",
      "echo PID=:${PID}:",
      "kill -9 ${PID}"
    ].join("\n")
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test 'CD5',
  'c fork-bomb is contained' do
    with_captured_log {
      run_cyber_dojo_sh({
        changed: { 'hiker.c' => C_FORK_BOMB },
        max_seconds: 3
      })
    }
    assert timed_out? ||
      printed?('fork()') ||
        daemon_error? ||
          no_such_container_error?, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD6',
  'shell fork-bomb is contained' do
    with_captured_log {
      run_cyber_dojo_sh({
        changed: { 'cyber-dojo.sh' => SHELL_FORK_BOMB },
        max_seconds: 3
      })
    }
    cant_fork = (os === :Alpine ? "can't fork" : 'Cannot fork')
    assert \
      timed_out? ||
        printed?(cant_fork) ||
          printed?('bomb') ||
            daemon_error? ||
              no_such_container_error?, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test 'DB3',
  'file-handles quickly become exhausted' do
    with_captured_log {
      run_cyber_dojo_sh({
        changed: { 'hiker.c' => FILE_HANDLE_BOMB },
        max_seconds: 3
      })
    }
    refute timed_out?, result
    #assert stdout.include?('fopen() != NULL'), result
    #assert_equal '', stderr gcov error
    #assert_equal 0, status
    #assert_equal 'green', colour
  end

  private # = = = = = = = = = = = = = = = = = = = = = =

  C_FORK_BOMB = <<~'CODE'
    #include "hiker.h"
    #include <stdio.h>
    #include <unistd.h>
    int answer(void)
    {
        for(;;)
        {
            int pid = fork();
            fprintf(stdout, "fork() => %d\n", pid);
            fflush(stdout);
            if (pid == -1)
                break;
        }
        return 6 * 7;
    }
  CODE

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  SHELL_FORK_BOMB = <<~CODE
    bomb()
    {
      echo "bomb"
      bomb | bomb &
    }
    bomb
  CODE

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  FILE_HANDLE_BOMB = <<~'CODE'
    #include "hiker.h"
    #include <stdio.h>
    int answer(void)
    {
      for (int i = 0;;i++)
      {
        char filename[42];
        sprintf(filename, "wibble%d.txt", i);
        FILE * f = fopen(filename, "w");
        if (f)
          fprintf(stdout, "fopen() != NULL %s\n", filename);
        else
        {
          fprintf(stdout, "fopen() == NULL %s\n", filename);
          break;
        }
      }
      return 6 * 7;
    }
  CODE

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  # :nocov:
  def printed?(text)
    (stdout+stderr).lines.any? { |line| line.include?(text) }
  end
  # :nocov:

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  # :nocov:
  def daemon_error?
    printed?('Error response from daemon: No such container') ||
      regexp?(/Error response from daemon: Container .* is not running/)
  end
  # :nocov:

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  # :nocov:
  def regexp?(pattern)
    (stdout+stderr) =~ pattern
  end
  # :nocov:

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  # :nocov:
  def no_such_container_error?
    stderr.start_with?('Error: No such container: cyber_dojo_runner_')
  end
  # :nocov:

end
