
TAR_FILE="${TMP_DIR}/cyber-dojo.tar"
TMP_DIR=$(mktemp -d /tmp/XXXXXX)

function send_tgz()
{
  truncate_file "${TMP_DIR}/stdout"
  truncate_file "${TMP_DIR}/stderr"
  tar -rf "${TAR_FILE}" -C "${TMP_DIR}" stdout stderr status
  text_filenames | tar -C / -rf ${TAR_FILE} -T -
  zip -c "${TAR_FILE}"
}

function text_filenames()
{
  find ${SANDBOX_DIR} -type f -exec \
    bash -c "is_truncated_text_file {} && unrooted {}" \;
}

function is_truncated_text_file()
{
  filename="${1}"
  if is_text_file "${filename}"; then
    truncate_file "${filename}"
    true
  else
    false
  fi
}

function is_text_file()
{
  filename="${1}"
  if file --mime-encoding ${filename} | grep -qv "${1}:\\sbinary"; then
    true
  elif [ $(stat -c%s "${filename}") -lt 2 ]; then
    # file incorrectly reports very small text files as binary.
    true
  else
    false
  fi
}

function truncate_file()
{
  # Beware; truncate can extend OR strink the size of a file.
  # The +1 is so Ruby can detect and lop off the final extra byte.
  filename="${1}"
  if [ $(stat -c%s "${filename}") -gt #{MAX_FILE_SIZE} ]; then
    truncate --size #{MAX_FILE_SIZE+1} "${filename}"
  fi
}

function unrooted()
{
  # tar prefer relative pathnames so strip leading /
  echo "${1:1}"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
trap "send_tgz" EXIT SIGTERM
cd "${SANDBOX_DIR}"
bash ./cyber-dojo.sh  \
       1> "${TMP_DIR}/stdout" \
       2> "${TMP_DIR}/stderr"
echo $? > "${TMP_DIR}/status"
