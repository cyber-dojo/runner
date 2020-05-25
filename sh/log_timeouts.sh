
function nodes()
{
  kubectl get nodes | tail -n +2 | cut -d' ' -f1
}

for node in $(nodes)
do
  line=$(kubectl describe node ${node} | grep prod | grep runner)
  pod=$(echo ${line} | cut -d' ' -f2)
  echo node=${node}
  echo pod=${pod}
  kubectl logs -n prod "${pod}" | grep POD_NAME | wc
done
