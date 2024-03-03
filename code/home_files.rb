# frozen_string_literal: true
module HomeFiles
  def home_files(sandbox_dir, max_file_size)
    {
      unrooted(MAIN_SH_PATH) => main_sh(sandbox_dir, max_file_size),
      unrooted(FS_CLEANERS_PATH) => file_system_cleaners
    }
  end

  HOME_DIR = '/home/sandbox'

  MAIN_SH_PATH      = "#{HOME_DIR}/cyber_dojo_main.sh"
  FS_CLEANERS_PATH  = "#{HOME_DIR}/cyber_dojo_fs_cleaners.sh"

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
  # There are important comments on the exit-status of
  # cyber_dojo_main.sh at the end of capture3_with_timeout.rb
  #
  # [0] --verbatim-files-from ensure filenames are not read as
  #     tar command options.
  #     Eg -J... is a tar compression option (but not on Ubuntu 16.04)
  # [1] Must be //; dont add space between // and ;
  # [2] /usr/bin/file reports small text files as binary.
  #     If size==0,1 assume a text file.
  # [3] grep -q is --quiet, we are generating filenames.
  # [4] truncates text files to MAX_FILE_SIZE+1 so
  #     runner.rb can detect the truncation.

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
        tar -rf "${TAR_FILE}" --verbatim-files-from --null -T <(print0_filenames) # [0]
        gzip  < "${TAR_FILE}"
      }
      function remove_binary_files()
      {
        print0_binary_filenames | xargs -0 rm
      }
      function print0_binary_filenames()
      {
        find #{sandbox_dir} -type f -exec bash -c "is_binary_file \\"{}\\"" \\; -print0 # [1]
      }
      function print0_filenames()
      {
        find #{sandbox_dir} -type f -print0
      }
      function is_binary_file()
      {
        local -r filename="${1}"
        local -r size=$(stat -c%s "${filename}")
        if [ "${size}" -lt 2 ]; then
          false # [2]
        elif file --mime-encoding "${filename}" | grep -q "${filename}:\\sbinary" ; then
          true # [3]
        else
          false
        fi
      }
      function truncate_large_files()
      {
        find #{sandbox_dir} -type f -exec bash -c "truncate_dont_extend \\"{}\\"" \\;
      }
      function truncate_dont_extend()
      {
        local -r filename="${1}"
        local -r size=$(stat -c%s "${filename}")
        if [ "${size}" -gt #{max_file_size} ] ; then
          truncate --size #{max_file_size + 1} "${filename}" # [4]
        fi
      }
      export -f is_binary_file
      export -f truncate_dont_extend
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
  # https://github.com/cyber-dojo-start-points/python-pytest/blob/master/start_point/cyber-dojo.sh
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
