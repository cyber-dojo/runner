
function cyber_dojo_reset_dir()
{
  for dirname in "$@"
  do
    cyber_dojo_delete_dirs ${dirname}
    mkdir -p ${dirname}
  done
}
