set -e

# --------------------------------------------------------------
# Text files under /sandbox are automatically returned.
source ~/cyber_dojo_delete_dirs.sh
source ~/cyber_dojo_delete_files.sh
source ~/cyber_dojo_reset_dirs.sh
export REPORT_DIR=${CYBER_DOJO_SANDBOX}/report
function cyber_dojo_enter()
{
  # Only return _newly_ generated reports.
  cyber_dojo_reset_dirs ${REPORT_DIR}
}
function cyber_dojo_exit()
{
  # Remove text files we don't want returned.
  cyber_dojo_delete_dirs .pytest_cache # ...
  #cyber_dojo_delete_files ...
}
cyber_dojo_enter
trap cyber_dojo_exit EXIT SIGTERM
# --------------------------------------------------------------


# CORE cyber-dojo.sh content goes here....
