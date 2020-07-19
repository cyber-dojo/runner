# frozen_string_literal: true
require_relative 'test_base'

class FeatureRobustNessTest < TestBase

  def self.id58_prefix
    '1B5'
  end

  def id58_setup
    context.puller.add(image_name)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test 'CD5', %w(
  fork-bomb does not run indefinitely
  ) do
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
    assert timed_out? ||
      printed?('fork()') ||
        daemon_error? ||
          no_such_container_error? ||
            gzip_exception?, pretty_result(:c_fork_bomb)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD6', %w(
  shell fork-bomb does not run indefinitely
  ) do
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
    cant_fork = (os === :Alpine ? "can't fork" : 'Cannot fork')
    assert \
      timed_out? ||
        printed?(cant_fork) ||
          printed?('bomb') ||
            daemon_error? ||
              no_such_container_error? ||
                gzip_exception?, pretty_result(:shell_fork_bomb)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test 'DB3', %w(
  file-handles quickly become exhausted
  ) do
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
    assert printed?('fopen() != NULL') ||
      daemon_error? ||
        no_such_container_error? ||
          gzip_exception?,  pretty_result(:file_handles)
  end

  private

  # :nocov:
  def printed?(text)
    (stdout+stderr).lines.any? { |line| line.include?(text) }
  end

  def daemon_error?
    printed?('Error response from daemon: No such container') ||
      regexp?(/Error response from daemon: Container .* is not running/)
  end

  def regexp?(pattern)
    (stdout+stderr) =~ pattern
  end

  def no_such_container_error?
    stderr.start_with?('Error: No such container: cyber_dojo_runner_')
  end

  def gzip_exception?
    logged?('Zlib::GzipFile::Error')
  end
  # :nocov:

end
