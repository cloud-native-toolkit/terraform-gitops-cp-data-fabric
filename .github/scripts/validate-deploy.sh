#!/usr/bin/env bash

GIT_REPO=$(cat git_repo)
GIT_TOKEN=$(cat git_token)

REGION=$(cat terraform.tfvars | grep -E "^region" | sed "s/region=//g" | sed 's/"//g')

aws configure set region ${REGION}
aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}

export KUBECONFIG=$(cat .kubeconfig)
NAMESPACE=$(jq -r '.cpd_namespace // "cp4d"' gitops-output.json)
COMPONENT_NAME=$(jq -r '.name // "my-module"' gitops-output.json)
BRANCH=$(jq -r '.branch // "main"' gitops-output.json)
SERVER_NAME=$(jq -r '.server_name // "default"' gitops-output.json)
LAYER=$(jq -r '.layer_dir // "2-services"' gitops-output.json)
TYPE=$(jq -r '.type // "base"' gitops-output.json)

sleep 600

mkdir -p .testrepo

git clone https://${GIT_TOKEN}@${GIT_REPO} .testrepo

cd .testrepo || exit 1

find . -name "*"

if [[ ! -f "argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml" ]]; then
  echo "ArgoCD config missing - argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml"
  exit 1
fi

echo "Printing argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml"
cat "argocd/${LAYER}/cluster/${SERVER_NAME}/${TYPE}/${NAMESPACE}-${COMPONENT_NAME}.yaml"

if [[ ! -f "payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml" ]]; then
  echo "Application values not found - payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml"
  exit 1
fi

echo "Printing payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml"
cat "payload/${LAYER}/namespace/${NAMESPACE}/${COMPONENT_NAME}/values.yaml"

count=0
until kubectl get namespace "${NAMESPACE}" 1>/dev/null 2>/dev/null || [[ $count -eq 20 ]]; do
  echo "Waiting for namespace: ${NAMESPACE}"
  count=$((count + 1))
  sleep 15
done

if [[ $count -eq 20 ]]; then
  echo "Timed out waiting for namespace: ${NAMESPACE}"
  exit 1
else
  echo "Found namespace: ${NAMESPACE}. Sleeping for 30 seconds to wait for everything to settle down"
  sleep 30
fi

POD=$(kubectl get pods -n ${NAMESPACE}  | awk '{print $1}' | grep "datafabric")
echo $POD
#Check Data Fabric POD Status
POD_STATUS=""
while [ true ]; do
  POD_STATUS=$(kubectl get po ${POD} -n ${NAMESPACE} | grep ${POD} |awk '{print $3}')
  echo "Waiting for POD ${POD} to be Completed. Current status : "${POD_STATUS}""
  if [ ${POD_STATUS} == "Completed" ]; then
    break
  fi
  sleep 60
done

# cleanup the resources
kubectl delete configmap datafabric-configmap -n ${NAMESPACE}
kubectl delete job datafabric-job -n ${NAMESPACE}

cd ..
rm -rf .testrepo


