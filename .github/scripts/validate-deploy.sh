#!/usr/bin/env bash

GIT_REPO=$(cat git_repo)
GIT_TOKEN=$(cat git_token)

export KUBECONFIG=$(cat .kubeconfig)
NAMESPACE=$(cat .namespace)
COMPONENT_NAME=$(jq -r '.name // "my-module"' gitops-output.json)
SERVER_NAME=$(jq -r '.server_name // "default"' gitops-output.json)
LAYER=$(jq -r '.layer_dir // "2-services"' gitops-output.json)
TYPE=$(jq -r '.type // "base"' gitops-output.json)
CPD_NAMESPACE=$(jq -r '.cpd_namespace // "cp4d"' gitops-output.json)
OPERATOR_NAMESPACE=$(jq -r '.operator_namespace // "cpd-operators"' gitops-output.json)

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

############################################################
#  Watson Knowledge Catalog Instance check
############################################################
str="No resources found"
while [ true ]; do
  SVC_CHECK=$(kubectl get WKC -n "${CPD_NAMESPACE}" 2>&1)
  echo $SVC_CHECK
  if [[ $SVC_CHECK == *"$str"* ]]; then
    echo "Waiting for WKC"
  else
    echo "WKC Available"
    break
  fi
done

INSTANCE_STATUS=""
while [ true ]; do
  INSTANCE_STATUS=$(kubectl get WKC wkc-cr -n "${CPD_NAMESPACE}" -o jsonpath='{.status.wkcStatus} {"\n"}')
  echo "Waiting for instance wkc-cr to be ready. Current status : "${INSTANCE_STATUS}""
  if [ $INSTANCE_STATUS == "Completed" ]; then
    break
  fi
  sleep 60
done
echo "Watson Knowledge Catalog WKC/wkc-cr is "${INSTANCE_STATUS}""

############################################################
# Watson Studio Instance check
############################################################
str="No resources found"
while [ true ]; do
  SVC_CHECK=$(kubectl get WS -n "${CPD_NAMESPACE}" 2>&1)
  echo $SVC_CHECK
  if [[ $SVC_CHECK == *"$str"* ]]; then
    echo "Waiting for WS"
  else
    echo "WS Available"
    break
  fi
done

INSTANCE_STATUS=""
while [ true ]; do
  INSTANCE_STATUS=$(kubectl get WS ws-cr -n "${CPD_NAMESPACE}" -o jsonpath='{.status.wsStatus} {"\n"}')
  echo "Waiting for instance ws-cr to be ready. Current status : "${INSTANCE_STATUS}""
  if [ $INSTANCE_STATUS == "Completed" ]; then
    break
  fi
  sleep 60
done
echo "Watson Studio WS/ws-cr is "${INSTANCE_STATUS}""

############################################################
# Watson Machine Learning Instance check
############################################################
str="No resources found"
while [ true ]; do
  SVC_CHECK=$(kubectl get WmlBase -n "${CPD_NAMESPACE}" 2>&1)
  echo $SVC_CHECK
  if [[ $SVC_CHECK == *"$str"* ]]; then
    echo "Waiting for WmlBase"
  else
    echo "WmlBase Available"
    break
  fi
done

INSTANCE_STATUS=""
while [ true ]; do
  INSTANCE_STATUS=$(kubectl get WmlBase wml-cr -n "${CPD_NAMESPACE}" -o jsonpath='{.status.wmlStatus} {"\n"}')
  echo "Waiting for instance wml-cr to be ready. Current status : "${INSTANCE_STATUS}""
  if [ $INSTANCE_STATUS == "Completed" ]; then
    break
  fi
  sleep 60
done
echo "Watson Machine Learning WmlBase/wkc-cr is "${INSTANCE_STATUS}""

############################################################
# Data Virtualization Service check
############################################################
str="No resources found"
while [ true ]; do
  SVC_CHECK=$(kubectl get DvService -n "${CPD_NAMESPACE}" 2>&1)
  echo $SVC_CHECK
  if [[ $SVC_CHECK == *"$str"* ]]; then
    echo "Waiting for DvService"
  else
    echo "DvService Available"
    break
  fi
done

INSTANCE_STATUS=""
while [ true ]; do
  INSTANCE_STATUS=$(kubectl get DvService dv-service -n "${CPD_NAMESPACE}" -o jsonpath='{.status.reconcileStatus} {"\n"}')
  echo "Waiting for instance dv-service to be ready. Current status : "${INSTANCE_STATUS}""
  if [ $INSTANCE_STATUS == "Completed" ]; then
    break
  fi
  sleep 60
done
echo "Data Virtualization DvService/"${INSTANCE_NAME}" is "${INSTANCE_STATUS}""

############################################################
# Data Virtualization Provision Instance check
############################################################
echo "DV Readiness Check"

dvenginePod=$(kubectl get pod -n $NAMESPACE --no-headers=true -l component=db2dv,name=dashmpp-head-0,role=db,type=engine | awk '{print $1}')
echo "DV engine head pod is $dvenginePod"

#Wait until the DV service is  ready
dvNotReady=1
iter=0
maxIter=120 #DV takes longer than BigSQL to become ready
while [ true ]; do
  oc logs -n $NAMESPACE $dvenginePod | grep "db2uctl markers get QP_START_PERFORMED" >/dev/null
  echo "dvNotReady "$dvNotReady""
  dvNotReady=$?
  if [ $dvNotReady -eq 0 ]; then
    break
  else
    echo "Waiting for the DV service to be ready. Recheck in 30 seconds"
    let iter=iter+1
    if [ $iter == $maxIter ]; then
      exit 1
    fi
    sleep 60
  fi
done

echo "All Prerequisites for Data Fabric are met. Proceeding with Data Fabric Configuration"

POD=$(kubectl get pods -n ${CPD_NAMESPACE} | awk '{print $1}' | grep "datafabric")
echo $POD
#Check Data Fabric POD Status
POD_STATUS=""
while [ true ]; do
  POD_STATUS=$(kubectl get po ${POD} -n ${CPD_NAMESPACE} | grep ${POD} | awk '{print $3}')
  echo "Waiting for POD ${POD} to be Completed. Current status : "${POD_STATUS}""
  if [ ${POD_STATUS} == "Completed" ]; then
    break
  fi
  sleep 60
done

sleep 120

# cleanup the resources
kubectl delete job datafabric-job -n ${CPD_NAMESPACE}
kubectl delete configmap datafabric-configmap -n ${CPD_NAMESPACE}


# Cleanup WKC
echo "Cleaning up UG"
UGCR=$(oc get ug -n "${CPD_NAMESPACE}" --no-headers | awk '{print $1}')
oc patch ug $UGCR -n "${CPD_NAMESPACE}" -p '{"metadata":{"finalizers":[]}}' --type=merge
oc delete ug -n "${CPD_NAMESPACE}" $UGCR

UGCRD=$(oc get crd -n "${CPD_NAMESPACE}" --no-headers | grep ug.wkc | awk '{print $1}')
oc delete crd -n "${CPD_NAMESPACE}" $UGCRD

echo "Cleaning up IIS"
IISCR=$(oc get iis -n "${CPD_NAMESPACE}" --no-headers | awk '{print $1}')
oc patch iis $IISCR -n "${CPD_NAMESPACE}" -p '{"metadata":{"finalizers":[]}}' --type=merge
oc delete iis -n "${CPD_NAMESPACE}" $IISCR

IISCRD=$(oc get crd -n "${CPD_NAMESPACE}" --no-headers | grep iis | awk '{print $1}')
oc delete crd -n "${CPD_NAMESPACE}" $IISCRD

oc delete sub ibm-cpd-iis-operator -n "${OPERATOR_NAMESPACE}"

IISCSV=$(oc get csv -n "${OPERATOR_NAMESPACE}" --no-headers | grep ibm-cpd-iis | awk '{print $1}')
oc delete csv $IISCSV -n "${OPERATOR_NAMESPACE}"

DB2OR=$(oc get operandrequests -n "${CPD_NAMESPACE}" --no-headers | grep iis-requests-db2uaas | awk '{print $1}')
oc delete operandrequests $DB2OR -n "${CPD_NAMESPACE}"

oc delete catsrc ibm-cpd-iis-operator-catalog -n openshift-marketplace

echo "Cleaning up WKC"
WKCCR=$(oc get wkc -n "${CPD_NAMESPACE}" --no-headers | awk '{print $1}')
oc patch wkc $WKCCR -n "${CPD_NAMESPACE}" -p '{"metadata":{"finalizers":[]}}' --type=merge
oc delete wkc -n "${CPD_NAMESPACE}" $WKCCR

WKCCRD=$(oc get crd -n "${CPD_NAMESPACE}" --no-headers | grep wkc.wkc | awk '{print $1}')
oc delete crd -n "${CPD_NAMESPACE}" $WKCCRD

oc delete sub ibm-cpd-wkc-operator-catalog-subscription -n "${OPERATOR_NAMESPACE}"

WKCCSV=$(oc get csv -n "${OPERATOR_NAMESPACE}" --no-headers | grep wkc | awk '{print $1}')
oc delete csv $WKCCSV -n "${OPERATOR_NAMESPACE}"

echo "Cleaning up operandrequests"
ORCERT=$(oc get operandrequests -n "${CPD_NAMESPACE}" --no-headers | grep cert-mgr-dep | awk '{print $1}')
oc delete operandrequest $ORCERT -n "${CPD_NAMESPACE}"
oc delete operandrequest wkc-requests-ccs -n "${CPD_NAMESPACE}"
oc delete operandrequest wkc-requests-datarefinery -n "${CPD_NAMESPACE}"
oc delete operandrequest wkc-requests-db2uaas -n "${CPD_NAMESPACE}"
oc delete operandrequest wkc-requests-iis -n "${CPD_NAMESPACE}"

oc delete catsrc ibm-cpd-wkc-operator-catalog -n openshift-marketplace

echo "Cleaning up installplan"
WKCIP=$(oc get ip -n "${OPERATOR_NAMESPACE}" --no-headers | grep wkc | awk '{print $1}')
IISIP=$(oc get ip -n "${OPERATOR_NAMESPACE}" --no-headers | grep iis | awk '{print $1}')
oc delete ip $WKCIP -n "${OPERATOR_NAMESPACE}"
oc delete ip $IISIP -n "${OPERATOR_NAMESPACE}"

cd ..
rm -rf .testrepo
