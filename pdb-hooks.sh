#!/usr/bin/env bash

NAMESPACE="prod"
ARRAY_COUNT=$(jq -r '. | length-1' $BINDING_CONTEXT_PATH)

run_hook() {
  if [[ $1 == "--config" ]] ; then
    config
  else
    trigger
  fi
}

config() {
  cat <<EOF
configVersion: v1
kubernetes:
- apiVersion: argoproj.io/v1alpha1
  kind: Rollout
  executeHookOnEvent:
  - Added
  - Deleted
  namespace:
    nameSelector:
      matchNames:
      - ${NAMESPACE}
EOF
}

trigger() {
  for IND in `seq 0 $ARRAY_COUNT`; do
    resourceEvent=$(jq -r ".[$IND].watchEvent" $BINDING_CONTEXT_PATH)
    resourceName=$(jq -r ".[$IND].object.metadata.name" $BINDING_CONTEXT_PATH)
    appid=${resourceName%-default}
    if [[ $resourceEvent == "Added" ]] ; then
      echo "Add PDB '${appid}'"
      kubectl -n ${NAMESPACE} get pdb clay-test -o json | \
        jq -r ".metadata.name=\"${appid}\" | .spec.selector.matchLabels[\"appid\"]=\"${appid}\" |
                .metadata |= with_entries(select([.key] | inside([\"name\", \"namespace\", \"labels\"])))" \
        | replace_or_create
    elif [[ $resourceEvent == "Deleted" ]]; then
      echo "Delete PDB '${appid}'"
      kubectl -n ${NAMESPACE} delete pdb ${appid}
    else
      echo "Do nothing"
    fi
  done
}

replace_or_create() {
  object=$(cat)

  if ! kubectl get -f - <<< "$object" >/dev/null 2>/dev/null; then
    kubectl create -f - <<< "$object" >/dev/null
  else
    kubectl replace --force -f - <<< "$object" >/dev/null
  fi
}

run_hook "$@"
