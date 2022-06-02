#!/bin/sh

############################################################
# Cloud pak for Data Instance check
############################################################
CPD_NAMESPACE="${ENV_CPD_NAMESPACE}"

STATUS=$(kubectl get Ibmcpd ibmcpd-cr -n "${CPD_NAMESPACE}" -o jsonpath="{.status.controlPlaneStatus}{'\n'}")
count=0
until [[ $STATUS == "Completed" ]] || [[ $count -eq 360 ]]; do
  echo "ibmcpd/ibmcpd-cr status: ${STATUS} "
  STATUS=$(kubectl get Ibmcpd ibmcpd-cr -n "${CPD_NAMESPACE}" -o jsonpath="{.status.controlPlaneStatus}{'\n'}")
  count=$((count + 1))
  sleep 15
done

if [[ $count -eq 360 ]]; then
  echo "Timed out waiting for ibmcpd/ibmcpd-cr to achieve Completed status"
  kubectl get ibmcpd ibmcpd-cr -n "${NAMESPACE}" -o yaml
  exit 1
fi

############################################################
#  Watson Knowledge Catalog Instance check
############################################################
INSTANCE_STATUS=""
while [ true ]; do
  INSTANCE_STATUS=$(kubectl get WKC wkc-cr -n "${CPD_NAMESPACE}" -o jsonpath='{.status.wkcStatus} {"\n"}')
  echo "Waiting for instance wkc-cr to be ready. Current status : "${INSTANCE_STATUS}""
  if [ $INSTANCE_STATUS == "Completed" ]; then
    break
  fi
  sleep 30
done
echo "Watson Knowledge Catalog WKC/wkc-cr is "${INSTANCE_STATUS}""

############################################################
# Watson Studio Instance check
############################################################
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
INSTANCE_STATUS=""
while [ true ]; do
  INSTANCE_STATUS=$(kubectl get WmlBase wml-cr -n "${CPD_NAMESPACE}" -o jsonpath='{.status.wmlStatus} {"\n"}')
  echo "Waiting for instance wml-cr to be ready. Current status : "${INSTANCE_STATUS}""
  if [ $INSTANCE_STATUS == "Completed" ]; then
    break
  fi
  sleep 30
done
echo "Watson Machine Learning WmlBase/wkc-cr is "${INSTANCE_STATUS}""

############################################################
# Data Virtualization Service check
############################################################
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
dvenginePod=$(kubectl get pod -n $CPD_NAMESPACE --no-headers=true -l component=db2dv,name=dashmpp-head-0,role=db,type=engine | awk '{print $1}')
echo "DV engine head pod is $dvenginePod"

#Wait until the DV service is  ready
dvNotReady=1
iter=0
maxIter=120 #DV takes longer than BigSQL to become ready
while [ true ]; do
    oc logs -n $CPD_NAMESPACE $dvenginePod | grep "db2uctl markers get QP_START_PERFORMED" >/dev/null
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
        sleep 30
    fi
done

echo "All Prerequisites for Data Fabric are met. Proceeding with Data Fabric Configuration"