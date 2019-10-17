#!/bin/bash

# Configure ********************************************************************
#

GC_REGION="europe-west1"
GC_ZONE="${GC_REGION}-c"
gcloud config set compute/region "${GC_REGION}" 2> /dev/null
gcloud config set compute/zone "${GC_ZONE}" 2> /dev/null

function configuration() {
  gcloud version
  echo
  echo "Region : $(gcloud config get-value compute/region)"
  echo "Zone   : $(gcloud config get-value compute/zone)"
}

K8S_CLUSTER_NAME="kubernetes-the-hard-way"

# Networking ******************************************************************
#

K8S_NETWORK="${K8S_CLUSTER_NAME}"
K8S_SUBNET="kubernetes"
K8S_FIREWALL_RULE_INTERNAL="${K8S_NETWORK}-allow-internal"
K8S_FIREWALL_RULE_EXTERNAL="${K8S_NETWORK}-allow-external"
K8S_PUBLIC_IP="${K8S_NETWORK}"

function create-network() {
  # VPC Network
  echo "Creating VCN..."
  gcloud compute networks create "${K8S_NETWORK}" --subnet-mode custom

  # VPC Subnet - 256 instance CIDR
  echo "Creating VCN subnet..."
  K8S_SUBNET_CIDR="10.240.0.0/24"
  gcloud compute networks subnets create "${K8S_SUBNET}" \
    --network "${K8S_NETWORK}" \
    --range "${K8S_SUBNET_CIDR}"

  # VPC Firewall Rules
  echo "Creating VCN firewall-rules..."
  # Allow internal communication across all protocols:
  gcloud compute firewall-rules create "${K8S_FIREWALL_RULE_INTERNAL}" \
    --allow tcp,udp,icmp \
    --network "${K8S_NETWORK}" \
    --source-ranges 10.240.0.0/24,10.200.0.0/16
  # Create a firewall rule that allows external SSH, ICMP, and HTTPS:
  gcloud compute firewall-rules create "${K8S_FIREWALL_RULE_EXTERNAL}" \
    --allow tcp:22,tcp:6443,icmp \
    --network "${K8S_NETWORK}" \
    --source-ranges 0.0.0.0/0
  
  # Assign public IP.
  echo "Creating VCN public ip address..."
  gcloud compute addresses create "${K8S_PUBLIC_IP}" \
    --region $(gcloud config get-value compute/region)
}

function delete-network() {
  echo "Deleting VCN public ip address..."
  gcloud compute addresses delete -q "${K8S_PUBLIC_IP}"
  echo "Deleting VCN firewall-rules..."
  gcloud compute firewall-rules delete -q "${K8S_FIREWALL_RULE_EXTERNAL}"
  gcloud compute firewall-rules delete -q "${K8S_FIREWALL_RULE_INTERNAL}"
  echo "Deleting VCN subnet..."
  gcloud compute networks subnets delete -q "${K8S_SUBNET}"
  echo "Deleting VCN..."
  gcloud compute networks delete -q "${K8S_NETWORK}"
}

function list-firewall-rules() {
  gcloud compute firewall-rules list --filter="network:${K8S_NETWORK}"
}

function get-static-ip() {
  # gcloud compute addresses list --filter="name=('kubernetes-the-hard-way')"
  gcloud compute addresses list --filter="name=('${K8S_NETWORK}')"
}

# Compute *********************************************************************
#

K8S_CONTROLER_INSTANCE_PREFIX="controller"
K8S_CONTROLLER_INSTANCE_PRIVATE_IP_PREFIX="10.240.0.1"
K8S_WORKER_INSTANCE_PREFIX="worker"
K8S_WORKER_INSTANCE_PRIVATE_IP_PREFIX="10.240.0.2"
K8S_INSTANCE_VOLUME_SIZE="200GB"
K8S_OS_IMG_FAMILY="ubuntu-1804-lts" 
K8S_OS_IMG_PROJECT="ubuntu-os-cloud"
K8S_MACHINE_TYPE="n1-standard-1"

function wait-controller-instances() {
  local finished="false"
  while [ "${finished}" != "true" ]; do
    local _res=0
    for i in 0 1 2; do
      local status=$(gcloud compute instances list | grep controller-${i} | awk '{print $NF}')
      echo "Current status: controller-${i} is '${status}'."
      if [ ! "${status}"='RUNNING' ]; then
        _res=$(echo ${_res} + 1 | bc)
      fi
    done
    if [ "${_res}" = 0 ]; then
      finished="true"
    else
      sleep 10
    fi
  done 
}

function create-controller-instances() {
  for i in 0 1 2; do
    echo "Creating instance: ${K8S_CONTROLER_INSTANCE_PREFIX}-${i}"
    gcloud compute instances create "${K8S_CONTROLER_INSTANCE_PREFIX}-${i}" \
      --async \
      --boot-disk-size "${K8S_INSTANCE_VOLUME_SIZE}" \
      --image-family "${K8S_OS_IMG_FAMILY}" \
      --image-project "${K8S_OS_IMG_PROJECT}" \
      --machine-type "${K8S_MACHINE_TYPE}" \
      --private-network-ip "${K8S_CONTROLLER_INSTANCE_PRIVATE_IP_PREFIX}${i}" \
      --subnet "${K8S_SUBNET}" \
      --can-ip-forward \
      --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
      --tags kubernetes-the-hard-way,controller
  done
  wait-controller-instances
}

function delete-controller-instances() {
  for i in 0 1 2; do
    echo "Deleting instance: ${K8S_CONTROLER_INSTANCE_PREFIX}-${i}"
    gcloud compute instances delete -q "${K8S_CONTROLER_INSTANCE_PREFIX}-${i}"
  done
}

function wait-worker-instances() {
  local finished="false"
  while [ "${finished}" != "true" ]; do
    local _res=0
    for i in 0 1 2; do
      local status=$(gcloud compute instances list | grep worker-${i} | awk '{print $NF}')
      echo "Current status: worker-${i} is '${status}'."
      if [ ! "${status}"='RUNNING' ]; then
        _res=$(echo ${_res} + 1 | bc)
      fi
    done
    if [ "${_res}" = 0 ]; then
      finished="true"
    else
      sleep 10
    fi
  done 
}

# gcloud compute operations describe  https://www.googleapis.com/compute/v1/projects/kubernetes-197019/zones/europe-west1-c/operations/operation-1530042588945-56f90cd015a6a-4d38ed85-8dbd6db7

# NB: The pod network cidr range is specified for each instance as gcloud metadata. 
function create-worker-instances() {
  for i in 0 1 2; do
    echo "Creating instance: ${K8S_WORKER_INSTANCE_PREFIX}-${i}"
    gcloud compute instances create "${K8S_WORKER_INSTANCE_PREFIX}-${i}" \
      --async \
      --boot-disk-size "${K8S_INSTANCE_VOLUME_SIZE}" \
      --image-family "${K8S_OS_IMG_FAMILY}" \
      --image-project "${K8S_OS_IMG_PROJECT}" \
      --machine-type "${K8S_MACHINE_TYPE}" \
      --metadata pod-cidr=10.200.${i}.0/24 \
      --private-network-ip "${K8S_WORKER_INSTANCE_PRIVATE_IP_PREFIX}${i}" \
      --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
      --subnet "${K8S_SUBNET}" \
      --can-ip-forward \
      --tags kubernetes-the-hard-way,worker
  done
  wait-worker-instances
}

function delete-worker-instances() {
  for i in 0 1 2; do
    echo "Deleting instance: ${K8S_WORKER_INSTANCE_PREFIX}-${i}"
    gcloud compute instances delete -q "${K8S_WORKER_INSTANCE_PREFIX}-${i}"
  done
}

function check-op-status() {
  local url=$1
  gcloud compute operations describe "${url}" | grep 'status:' | awk '{print $2}'
}

function verify-instances() {
  gcloud compute instances list
}

# IAAS *************************************************************************
#

function create-infra() {
  create-network
  create-controller-instances
  create-worker-instances
}

function delete-infra() {
  delete-worker-instances
  delete-controller-instances
  delete-network
}

# Main ************************************************************************
#

# If provided, execute the specified function.
if [ ! -z "$1" ]; then
  $1
fi
