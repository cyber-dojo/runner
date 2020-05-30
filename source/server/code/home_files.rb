
module HomeFiles

  def home_files(sandbox_dir, max_file_size)
    {
      unrooted(MAIN_SH_PATH) => main_sh(sandbox_dir, max_file_size)
    }
  end

  def unrooted(filename)
    filename[1..-1]
  end

  MAIN_SH_PATH     = '/home/sandbox/main.sh'

  # - - - - - - - - - - - - - - - - - - - - - -
  # [0] Ensure filenames are not read as tar command options.
  #     Eg -J... is a tar compression option.
  #     Not on Ubuntu 16.04
  # [1] Must be //; dont add space between // and ;
  # [2] grep -q is --quiet, we are generating filenames
  #     grep -v is --invert-match
  # [3] file incorrectly reports very small files as binary.
  #     If size==0,1 assume a text file.
  # [4] truncates text files to MAX_FILE_SIZE+1
  #     so truncated?() can detect the truncation.
  # [5] tar prefers relative filenames

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

end
