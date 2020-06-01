
NAMESPACE="${1:-prod}"

function nodes()
{
  kubectl get nodes | tail -n +2 | cut -d' ' -f1
}

for node in $(nodes)
do
  line=$(kubectl describe node ${node} | grep "${NAMESPACE}" | grep runner)
  pod=$(echo ${line} | cut -d' ' -f2)
  echo
  echo node=${node}
  echo pod=${pod}
  kubectl logs -n "${NAMESPACE}" "${pod}"
done
