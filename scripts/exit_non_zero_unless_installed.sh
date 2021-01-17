
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit_non_zero_unless_installed()
{
  local -r command="${1}"
  echo "Checking ${command} is installed..."
  if ! installed "${command}" ; then
    stderr "${command} is not installed!"
    exit 42
  else
    echo It is
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
installed()
{
  if hash "${1}" 2> /dev/null; then
    true
  else
    false
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
stderr()
{
  local -r message="${1}"
  >&2 echo "ERROR: ${message}"
}

