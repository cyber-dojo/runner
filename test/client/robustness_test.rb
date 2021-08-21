require_relative '../test_base'

class RobustNessTest < TestBase

  def self.id58_prefix
    '1B5'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test 'CD5', %w(
  fork-bomb does not run indefinitely
  ) do
    set_context
    run_cyber_dojo_sh(
      traffic_light: TrafficLightStub::amber,
      max_seconds: 3,
      changed: { 'hiker.c' =>
        <<~'C_FORK_BOMB'
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
        C_FORK_BOMB
      }
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD6', %w(
  shell fork-bomb does not run indefinitely
  ) do
    set_context
    run_cyber_dojo_sh(
      traffic_light: TrafficLightStub::amber,
      max_seconds: 3,
      changed: { 'cyber-dojo.sh' =>
        <<~'SHELL_FORK_BOMB'
        bomb()
        {
          echo "bomb"
          bomb | bomb &
        }
        bomb
        SHELL_FORK_BOMB
      }
    )
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test 'DB3', %w(
  file-handles quickly become exhausted
  ) do
    set_context
    run_cyber_dojo_sh(
      traffic_light: TrafficLightStub::amber,
      max_seconds: 10,
      changed: { 'hiker.c' =>
        <<~'FILE_HANDLE_BOMB'
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
        FILE_HANDLE_BOMB
      }
    )
  end

end
