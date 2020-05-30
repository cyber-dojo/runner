
module HomeFiles

  # - - - - - - - - - - - - - - - - - - - - - -
  # main.sh
  # o) runs /sandbox/cyber-dojo.sh
  # o) captures its stdout/stderr/status
  # o) writes them to tgz file on stdout
  # o) reads all text files under /sandbox
  # o) writes them to tgz file in stdout

  def home_files(sandbox_dir, max_file_size)
    {
      unrooted(MAIN_SH_PATH) => main_sh(sandbox_dir, max_file_size),
      unrooted(DELETE_DIRS_PATH) => DELETE_DIRS,
      unrooted(DELETE_FILES_PATH) => DELETE_FILES,
      unrooted(RESET_DIRS_PATH) => RESET_DIRS
    }
  end

  HOME_DIR = '/home/sandbox'

  MAIN_SH_PATH      = "#{HOME_DIR}/main.sh"
  DELETE_DIRS_PATH  = "#{HOME_DIR}/delete_dirs.sh"
  DELETE_FILES_PATH = "#{HOME_DIR}/delete_files.sh"
  RESET_DIRS_PATH   = "#{HOME_DIR}/reset_dirs.sh"

  def unrooted(filename)
    filename[1..-1] # tar prefers relative paths
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # [0] Ensure filenames are not read as tar command options.
  #     Eg -J... is a tar compression option. Not on Ubuntu 16.04
  # [1] Must be //; dont add space between // and ;
  # [2] grep -q is --quiet, we are generating filenames
  #     grep -v is --invert-match
  # [3] /usr/bin/file reports small text files as binary.
  #     If size==0,1 assume a text file.
  # [4] truncates text files to MAX_FILE_SIZE+1 so
  #     runner.rb's truncated?() can detect the truncation.
  # [5] tar prefers relative paths

  def main_sh(sandbox_dir, max_file_size)
    <<~SHELL.strip
    TMP_DIR=$(mktemp -d /tmp/XXXXXX)
    TAR_FILE="${TMP_DIR}/cyber-dojo.tar"
    function send_tgz()
    {
      local -r signal="${1}"
      # >&2 echo "signal:${signal}:"
      tar -rf "${TAR_FILE}" -C ${TMP_DIR} stdout stderr status
      truncated_text_filenames | \
        tar -rf ${TAR_FILE} \
        -C / \
        --verbatim-files-from -T - # [0]
      gzip < "${TAR_FILE}"
    }
    function truncated_text_filenames()
    {
      find #{sandbox_dir} -type f -exec \\
        bash -c "is_truncated_text_file {} && unrooted {}" \\; # [1]
    }
    function is_truncated_text_file()
    {
      local -r filename="${1}"
      local -r size=$(stat -c%s "${filename}")
      if is_text_file "${filename}" "${size}" ; then
        truncate_dont_extend "${filename}" "${size}"
        true
      else
        false
      fi
    }
    function is_text_file()
    {
      local -r filename="${1}"
      local -r size="${2}"
      if file --mime-encoding ${filename} | grep -qv "${filename}:\\sbinary" ; then # [2]
        true
      elif [ "${size}" -lt 2 ]; then # [3]
        true
      else
        false
      fi
    }
    function truncate_dont_extend()
    {
      local -r filename="${1}"
      local -r size="${2}"
      if [ "${size}" -gt #{max_file_size} ] ; then
        truncate --size #{max_file_size+1} "${filename}" # [4]
      fi
    }
    function unrooted()
    {
      local -r filename="${1}"
      echo "${filename:1}" # [5]
    }
    export -f is_truncated_text_file
    export -f is_text_file
    export -f truncate_dont_extend
    export -f unrooted
    # - - - - - - - - - - - - - - - - - - -
    trap "send_tgz EXIT" EXIT
    trap "send_tgz TERM" SIGTERM
    cd #{sandbox_dir}
    bash ./cyber-dojo.sh         \
             1> "${TMP_DIR}/stdout" \
             2> "${TMP_DIR}/stderr"
    printf $? > "${TMP_DIR}/status"
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -
  # Text files (under /sandbox) are automatically returned
  # to the browser; cyber-dojo.sh should:
  # o) remove text files its doesn't want returned to the browser.
  #      cyber_dojo_delete_dirs()
  #      cyber_dojo_delete_files()
  # o) reset the REPORT_DIR to return only newly generated reports.
  #      cyber_dojo_reset_dirs()

  DELETE_DIRS =
    <<~SHELL.strip
    function cyber_dojo_delete_dirs()
    {
      for dirname in "$@"
      do
          rm -rf "${dirname}" 2> /dev/null || true
      done
    }
    SHELL

  DELETE_FILES =
    <<~SHELL.strip
    function cyber_dojo_delete_files()
    {
      for filename in "$@"
      do
          rm "${filename}" 2> /dev/null || true
      done
    }
    SHELL

  RESET_DIRS =
    <<~SHELL.strip
    function cyber_dojo_reset_dir()
    {
      for dirname in "$@"
      do
        cyber_dojo_delete_dirs ${dirname}
        mkdir -p ${dirname}
      done
    }
    SHELL

end
