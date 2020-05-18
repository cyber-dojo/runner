# frozen_string_literal: true
require_relative 'test_base'

class RobustNessTest < TestBase

  def self.id58_prefix
    '1B5'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test 'CD5',
  'c fork-bomb is contained' do
    run_cyber_dojo_sh({
      max_seconds: 2,
      changed: { 'hiker.c' =>
        <<~'SOURCE'
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
        SOURCE
      }
    })
    diagnostic = '/tmp/text_filenames.sh: fork: retry: Resource temporarily unavailable'
    assert log.empty? || log.include?(diagnostic), pretty_result(:log)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test 'DB3',
  'file-handles quickly become exhausted' do
    run_cyber_dojo_sh({
      max_seconds: 2,
      changed: { 'hiker.c' =>
        <<~'SOURCE'
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
        SOURCE
        }
    })
    assert log.empty?, pretty_result(:log_empty)
    assert stdout.empty? || stdout.include?('fopen() != NULL'), pretty_result(:stdout)
    assert stderr.include?('profiling:/sandbox/hiker.gcda:Cannot open'), stderr
    assert_equal 0, status, :status
    assert_equal 'green', colour, :colour
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD4',
  'cyber-dojo.sh killing its own processes is contained' do
    run_cyber_dojo_sh_kill_pid_for('init')
    assert log.empty?, pretty_result(:log_empty)

    run_cyber_dojo_sh_kill_pid_for('main.sh')
    assert log.empty?, pretty_result(:log_empty)

    run_cyber_dojo_sh_kill_pid_for('cyber-dojo.sh')
    assert_logged([
      '/tmp/main.sh: line 22:    ',
      '12 Killed                  ',
      'bash ./cyber-dojo.sh > "${TMP_DIR}/stdout" 2> "${TMP_DIR}/stderr'
    ].join(''))
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD6',
  'shell fork-bomb is contained (bash)' do
    run_cyber_dojo_sh({
      max_seconds: 2,
      changed: { 'cyber-dojo.sh' =>
        <<~'SOURCE'
        bomb()
        {
          echo "bomb"
          bomb | bomb &
        }
        bomb
        SOURCE
      }
    })
    assert timed_out?, pretty_result(:timed_out)
    message_1 = '/tmp/text_filenames.sh: fork: retry: Resource temporarily unavailable'
    message_2 = '/tmp/main.sh: fork: retry: Resource temporarily unavailable'
    assert log.include?(message_1) || log.include?(message_2), pretty_result(:resource_unavailable)
    assert stdout.empty?, pretty_result(:stdout_empty)
    assert stderr.empty?, pretty_result(:stderr_empty)
    assert_equal 42, status, pretty_result(:status)
  end

  private

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

  def assert_logged(expected)
    diagnostic = "#{pretty_result(:log)}\nExpected log to contain: #{expected}"
    assert log.include?(expected), diagnostic
  end

end
