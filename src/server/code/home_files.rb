
module HomeFiles

  def home_files(sandbox_dir, max_file_size)
    {
      unrooted(MAIN_SH_PATH) => main_sh(sandbox_dir),
      unrooted(SEND_TGZ_SH_PATH) => send_tgz_sh(sandbox_dir, max_file_size)
    }
  end

  def unrooted(filename)
    filename[1..-1]
  end

  SEND_TGZ_SH_PATH = '/home/sandbox/send_tgz.sh'
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

  def send_tgz_sh(sandbox_dir, max_file_size)
    <<~SHELL.strip
    function send_tgz()
    {
      truncated_text_filenames | tar                \\
        -C /                                        \\
        -zcf                    `# create tgz file` \\
        -                       `# write to stdout` \\
        --verbatim-files-from   `# [0]`             \\
        -T                      `# using filenames` \\
        -                       `# from stdin`
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
    export -f send_tgz
    export -f truncated_text_filenames
    export -f is_truncated_text_file
    export -f is_text_file
    export -f truncate_dont_extend
    export -f unrooted
    SHELL
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def main_sh(sandbox_dir)
    <<~SHELL.strip
    TMP_DIR=$(mktemp -d /tmp/XXXXXX)
    function send_sss()
    {
      local -r signal="${1}"
      { echo stdout; echo stderr; echo status; } \
        | tar -C ${TMP_DIR} -zcf - --verbatim-files-from -T -
    }
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    trap "send_sss EXIT" EXIT
    trap "send_sss TERM" SIGTERM
    cd #{sandbox_dir}
    bash ./cyber-dojo.sh         \
             1> "${TMP_DIR}/stdout" \
             2> "${TMP_DIR}/stderr"
    printf $? > "${TMP_DIR}/status"

    # >&2 echo "stdout:$(cat ${TMP_DIR}/stdout):"
    # >&2 echo "stderr:$(cat ${TMP_DIR}/stderr):"
    # >&2 echo "status:$(cat ${TMP_DIR}/status):"

    SHELL
  end

end
