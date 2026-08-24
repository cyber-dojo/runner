module HomeFiles
  def home_files(sandbox_dir, max_file_size)
    {
      unrooted(MAIN_SH_PATH) => main_sh(sandbox_dir, max_file_size),
      unrooted(FS_CLEANERS_PATH) => file_system_cleaners
    }
  end

  HOME_DIR = '/home/sandbox'.freeze

  MAIN_SH_PATH      = "#{HOME_DIR}/cyber_dojo_main.sh".freeze
  FS_CLEANERS_PATH  = "#{HOME_DIR}/cyber_dojo_fs_cleaners.sh".freeze

  def unrooted(filename)
    filename[1..] # tar prefers relative paths
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # The Docker container calls cyber_dojo_main.sh which
  # installs the send_tgz() in an EXIT trap handler.
  # send_tgz() multiplexes cyber-dojo.sh's stdout/stderr/status
  # into a tgz file which becomes the container's stdout
  # which is read in capture3_with_timeout.rb
  #
  # Compression is at level 1. The pipe to the runner is local, so the
  # smaller payload buys almost no transfer time; what gzip is here for is
  # its CRC32 and length trailer. A tar alone has no integrity check that
  # Ruby will act on, and garbage bytes parse into entries with junk names
  # that would reach the browser. Level 1 costs about a third of the default
  # level and keeps most of the compression, and every language image
  # accepts it: docs/profiling/check_gzip_level_1_flag_support.sh surveyed
  # alpine 3.11 to 3.24, debian 9 to 13 and ubuntu 18.04 to 24.04. Level 0
  # is not an option; GNU gzip rejects it.
  # See docs/profiling/where-the-traffic-light-time-goes.txt
  #
  # There are important comments on the exit-status of
  # cyber_dojo_main.sh at the end of capture3_with_timeout.rb
  #
  # [0] --verbatim-files-from ensure filenames are not read as
  #     tar command options.
  #     Eg -J... is a tar compression option (but not on Ubuntu 16.04)
  #     We used to run print0_filenames with process substitution:
  #       tar -rf "${TAR_FILE}" --verbatim-files-from --null -T <(print0_filenames)
  #     Process substitution has historically failed in certain Docker container configurations.
  #     Bash process substitution <(cmd) uses /dev/fd/N symlinks, which resolve via /proc/self/fd.
  #     Docker's default AppArmor profile does restrict some /proc access by design.
  #     So prefer not to use process substitution.
  #
  # The walk makes one `file` call for the whole sandbox rather than one per
  # file, and selects the oversized files with find rather than stat, so its
  # cost is a handful of processes instead of six per file. `file` startup
  # dominates its runtime, so batching is worth about 44x on an Alpine image.
  #
  # [1] file reports an empty or a one-byte text file as binary, so -size +1c
  #     holds them out of the scan and they survive as text. Selecting on size
  #     here is also what removes stat from the walk.
  # [2] --print0 writes a NUL directly after each filename, ahead of the ":"
  #     separator, which is what makes the output parseable. Without it a kata
  #     file named "awkward: binary.txt" prints as
  #     "awkward: binary.txt: us-ascii" and any split on ": " reads the verdict
  #     as binary and deletes a text file. The NUL also carries filenames
  #     containing newlines safely.
  #     docs/profiling/check_batched_file_output_parsing.sh demonstrates that
  #     ambiguity and confirms --print0 on all 100 language images.
  # [3] The verdict line for the filename just read, ": <encoding>" padded with
  #     spaces. Only the single word "binary" means delete.
  # [4] truncates text files to MAX_FILE_SIZE+1 so
  #     runner.rb can detect the truncation.
  # [5] --magic-file /dev/null suppresses the 10.3MB magic database that
  #     file loads on every invocation. --mime-encoding does not consult it
  #     to reach its answer: a PDF, PostScript or GIF file whose bytes are
  #     all ASCII reports us-ascii whether the database is loaded or not.
  #     Suppressing it takes this call from 7185us to 232us per file on an
  #     Alpine based image, which is below the cost of spawning bash.
  #     docs/profiling/compare_magic_db_verdicts.sh gates the claim that no
  #     file changes side of the binary/non-binary boundary, and
  #     docs/profiling/time_file_without_magic_db.sh measures the saving.
  #     The long flag is safe here, unlike xargs --null which busybox
  #     rejects: docs/profiling/check_magic_file_flag_support.sh surveyed
  #     all 100 language images, spanning alpine 3.20 to 3.24, debian 11 to
  #     13, ubuntu 22.04 and 24.04, and file 5.39 to 5.47, and every one
  #     accepts it and returns the same verdicts.
  #     Note this does not make [2] unnecessary: an empty or one-byte text
  #     file is reported as binary either way.

  def main_sh(sandbox_dir, max_file_size)
    <<~SHELL.strip
      TMP_DIR=$(mktemp -d /tmp/XXXXXX)
      TAR_FILE="${TMP_DIR}/cyber-dojo.tar"
      function send_tgz()
      {
        touch ${TMP_DIR}/stdout && mv ${TMP_DIR}/stdout /tmp
        touch ${TMP_DIR}/stderr && mv ${TMP_DIR}/stderr /tmp
        touch ${TMP_DIR}/status && mv ${TMP_DIR}/status /tmp
        remove_binary_files
        truncate_large_files
        tar -rf "${TAR_FILE}" /tmp/stdout /tmp/stderr /tmp/status
        print0_filenames | tar -rf "${TAR_FILE}" --verbatim-files-from --null -T - # [0]
        gzip -1 < "${TAR_FILE}"
      }
      function remove_binary_files()
      {
        print0_binary_filenames | xargs -0 rm
      }
      function print0_binary_filenames()
      {
        # [1] [2] [5]
        find #{sandbox_dir} -type f -size +1c -print0 \\
          | xargs -0 file --print0 --magic-file /dev/null --mime-encoding \\
          | print0_names_with_binary_verdict
      }
      function print0_names_with_binary_verdict()
      {
        local filename verdict
        while IFS= read -r -d '' filename; do
          IFS= read -r verdict || verdict='' # [3]
          if [ "${verdict##*[[:space:]]}" = binary ]; then
            printf '%s\\0' "${filename}"
          fi
        done
      }
      function print0_filenames()
      {
        find #{sandbox_dir} -type f -print0
      }
      function truncate_large_files()
      {
        find #{sandbox_dir} -type f -size +#{max_file_size}c -print0 \\
          | xargs -0 truncate --size #{max_file_size + 1} # [4]
      }
      # - - - - - - - - - - - - - - - - - - -
      trap send_tgz EXIT
      cd #{sandbox_dir}
      bash ./cyber-dojo.sh         \
               1> "${TMP_DIR}/stdout" \
               2> "${TMP_DIR}/stderr"
      printf $? > "${TMP_DIR}/status"
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # cyber-dojo.sh should remove text files it doesn't want
  # returned; it can use these bash functions:
  #
  #    cyber_dojo_delete_dirs
  #    cyber_dojo_delete_files
  #
  # For example, see:
  # https://github.com/cyber-dojo-start-points/python-pytest/blob/main/start_point/cyber-dojo.sh
  # which contains this to remove the .pytest_cache dir.
  #
  #    function cyber_dojo_exit()
  #    {
  #        cyber_dojo_delete_dirs .pytest_cache
  #    }
  #    trap cyber_dojo_exit EXIT SIGTERM
  #
  # The bash function:
  #
  #      cyber_dojo_reset_dirs ...
  #
  # exists for historical reasons. It is retained only for backward
  # compatibility with old katas.

  def file_system_cleaners
    <<~SHELL.strip
      function cyber_dojo_delete_dirs()
      {
        for dirname in "$@"
        do
            rm -rf "${dirname}" 2> /dev/null || true
        done
      }
      function cyber_dojo_delete_files()
      {
        for filename in "$@"
        do
            rm "${filename}" 2> /dev/null || true
        done
      }
      function cyber_dojo_reset_dirs()
      {
        for dirname in "$@"
        do
          cyber_dojo_delete_dirs ${dirname}
          mkdir -p ${dirname}
        done
      }
    SHELL
  end
end
