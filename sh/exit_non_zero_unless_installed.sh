

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit_non_zero_unless_installed()
{
  for dependent in "$@"
  do
    if ! installed "${dependent}" ; then
      >&2 echo ERROR: "${dependent}" is not installed
      exit 42
    fi
  done
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
installed()
{
  local -r dependent="${1}"
  if hash "${dependent}" 2> /dev/null; then
    true
  else
    false
  fi
}

