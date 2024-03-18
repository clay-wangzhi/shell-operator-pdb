#!/usr/bin/env bash

NAMESPACE="prod"

pdb_templates() {
  cat <<EOF
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: clay-test
  namespace: ${NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      appid: clay-test
EOF
}

replace_or_create() {
  object=$(cat)

  if ! kubectl get -f - <<< "$object" >/dev/null 2>/dev/null; then
    kubectl create -f - <<< "$object" >/dev/null
  else
    kubectl replace --force -f - <<< "$object" >/dev/null
  fi
}

init() {
  echo "Init PDB templates"
  pdb_templates | replace_or_create
  for resourceName in $(kubectl -n ${NAMESPACE} get rollouts.argoproj.io | grep default | awk '{print $1}'); do
    appid=${resourceName%-default} 
    echo "Init Add PDB '${appid}'"
    kubectl -n ${NAMESPACE} get pdb clay-test -o json | \
      jq -r ".metadata.name=\"${appid}\" | .spec.selector.matchLabels[\"appid\"]=\"${appid}\" |
              .metadata |= with_entries(select([.key] | inside([\"name\", \"namespace\", \"labels\"])))" \
      | replace_or_create
  done
}

init "$@"
