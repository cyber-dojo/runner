
function cyber_dojo_delete_files()
{
  for filename in "$@"
  do
      rm "${filename}" 2> /dev/null || true
  done
}
