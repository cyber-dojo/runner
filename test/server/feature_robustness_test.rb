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
      max_seconds: 3,
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
    #message_1 = '/tmp/text_filenames.sh: fork: retry: Resource temporarily unavailable'
    #message_2 = '/tmp/main.sh: fork: retry: Resource temporarily unavailable'
    #message_3 = 'find: cannot fork: Resource temporarily unavailable'
    #assert log_empty? ||
    #  log.include?(message_1) ||
    #  log.include?(message_2) ||
    #  log.include?(message_3), pretty_result(:resource_unavailable)
    assert ['red','amber','green'].include?(colour), pretty_result(:colour)
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
    #assert log_empty?, pretty_result(:log_empty)
    #assert stdout.empty? || stdout.include?('fopen() != NULL'), pretty_result(:stdout)
    #assert stderr.empty? || stderr.include?('profiling:/sandbox/hiker.gcda:Cannot open'), pretty_result(:stderr)
    #assert [0,42].include?(status), pretty_result(:status)
    assert ['red','amber','green'].include?(colour), pretty_result(:colour)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD4',
  'cyber-dojo.sh killing its own processes is contained' do
    run_cyber_dojo_sh_kill_pid_for('init')
    assert ['red','amber','green'].include?(colour), pretty_result(:colour)

    run_cyber_dojo_sh_kill_pid_for('main.sh')
    assert ['red','amber','green'].include?(colour), pretty_result(:colour)

    run_cyber_dojo_sh_kill_pid_for('cyber-dojo.sh')
    assert ['red','amber','green'].include?(colour), pretty_result(:colour)
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
    #message_1 = '/tmp/text_filenames.sh: fork: retry: Resource temporarily unavailable'
    #message_2 = '/tmp/main.sh: fork: retry: Resource temporarily unavailable'
    #message_3 = 'find: cannot fork: Resource temporarily unavailable'
    #assert log_empty? ||
    #  log.include?(message_1) ||
    #  log.include?(message_2) ||
    #  log.include?(message_3), pretty_result(:resource_unavailable)

    #assert stdout.empty?, pretty_result(:stdout_empty)
    #assert stderr.empty?, pretty_result(:stderr_empty)
    #assert_equal 42, status, pretty_result(:status) # Gzip Error
    assert ['red','amber','green'].include?(colour), pretty_result(:colour)
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

end
