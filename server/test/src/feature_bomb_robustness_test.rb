require_relative 'test_base'

class BombRobustNessTest < TestBase

  def self.hex_prefix
    '1B5'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD5',
  '[C,assert] fork-bomb does not run indefinitely' do
    in_kata {
      with_captured_log {
        run_cyber_dojo_sh({
          changed_files: { 'hiker.c' => C_FORK_BOMB },
            max_seconds: 3
        })
      }
      assert timed_out? || printed?('All tests passed'), result
      assert timed_out? || printed?('fork()'), result
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD6',
  'shell fork-bomb does not run indefinitely' do
    in_kata {
      with_captured_log {
        run_cyber_dojo_sh({
          changed_files: { 'cyber-dojo.sh' => SHELL_FORK_BOMB },
            max_seconds: 3
        })
      }
      cant_fork = (os == :Alpine ? "can't fork" : 'Cannot fork')
      assert timed_out? ||
        printed?(cant_fork) ||
          printed?('bomb'), result
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'DB3',
  '[C,assert] file-handles quickly become exhausted' do
    in_kata {
      run_cyber_dojo_sh({
        changed_files: { 'hiker.c' => FILE_HANDLE_BOMB },
          max_seconds: 3
      })
      assert printed?('fopen() != NULL'),  result
    }
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

  def printed?(text)
    count = (stdout+stderr).lines.count { |line| line.include?(text) }
    count > 0
  end

end
