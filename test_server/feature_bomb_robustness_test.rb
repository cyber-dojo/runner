require_relative 'test_base'

class BombRobustNessTest < TestBase

  def self.hex_prefix
    '1B5'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'CD5',
  '[C,assert] fork-bomb does not run indefinitely' do
    with_captured_log {
      run_cyber_dojo_sh({
        changed: { 'hiker.c' => C_FORK_BOMB },
        max_seconds: 3
      })
    }
    assert timed_out? || printed?('fork()') || daemon_error?, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD6',
  'shell fork-bomb does not run indefinitely' do
    with_captured_log {
      run_cyber_dojo_sh({
        changed: { 'cyber-dojo.sh' => SHELL_FORK_BOMB },
        max_seconds: 3
      })
    }

    cant_fork = (os === :Alpine ? "can't fork" : 'Cannot fork')
    assert timed_out? || printed?(cant_fork) || printed?('bomb') || daemon_error?, result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'DB3',
  '[C,assert] file-handles quickly become exhausted' do
    with_captured_log {
      run_cyber_dojo_sh({
        changed: { 'hiker.c' => FILE_HANDLE_BOMB },
        max_seconds: 3
      })
    }
    assert printed?('fopen() != NULL') || daemon_error?,  result
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '62B',
  %w( a crippled container, eg from a fork-bomb, returns everything unchanged ) do
    all_OSes.each do |os|
      set_OS(os)
      stub = BashStubTarPipeOut.new('fail')
      @externals = Externals.new({ 'bash' => stub })
      with_captured_log { run_cyber_dojo_sh }
      assert stub.fired_once?
      assert_created({})
      assert_deleted([])
      assert_changed({})
    end
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

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  # :nocov:
  def daemon_error?
    printed?('Error response from daemon: No such container') ||
      regex?(/Error response from daemon: Container .* is not running/)
  end
  # :nocov:

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  # :nocov:
  def regexp?(pattern)
    (stdout+stderr) =~ pattern
  end
  # :nocov:

end
