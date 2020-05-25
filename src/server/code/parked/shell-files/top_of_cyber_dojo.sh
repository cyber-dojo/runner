set -e

# --------------------------------------------------------------
# Text files (under /sandbox) are automatically returned.
source ~/delete_dirs.sh
source ~/delete_files.sh
source ~/reset_dirs.sh
export CYBER_DOJO_REPORT_DIR=${CYBER_DOJO_SANDBOX}/report
function cyber_dojo_enter()
{
  # Reset the REPORT_DIR to return only newly generated reports.
  cyber_dojo_reset_dirs ${CYBER_DOJO_REPORT_DIR}
}
# --------------------------------------------------------------
trap cyber_dojo_exit EXIT SIGTERM
function cyber_dojo_exit()
{
  # Remove text files we don't want returned.
  cyber_dojo_delete_dirs .pytest_cache # ...
  #cyber_dojo_delete_files ...
}
# --------------------------------------------------------------
cyber_dojo_enter

# CORE cyber-dojo.sh content goes here....
