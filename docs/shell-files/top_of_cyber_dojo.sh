set -e

# ------------------------------------------------------------------------
source /tmp/cyber_dojo/delete_dirs.sh
source /tmp/cyber_dojo/delete_files.sh
source /tmp/cyber_dojo/reset_dirs.sh
# Text files (under /sandbox) are automatically returned.
export CYBER_DOJO_REPORT_DIR=${CYBER_DOJO_SANDBOX}/report
function cyber_dojo_enter()
{
  # Reset the REPORT_DIR to return only newly generated reports.
  cyber_dojo_reset_dirs ${CYBER_DOJO_REPORT_DIR}
}
cyber_dojo_enter
# ------------------------------------------------------------------------
trap cyber_dojo_exit EXIT SIGTERM
function cyber_dojo_exit()
{
  # Remove text files we don't want returned.
  cyber_dojo_delete_dirs .pytest_cache # ...
  #cyber_dojo_delete_files ...
}
# ------------------------------------------------------------------------

main cyber-dojo.sh content goes here....
