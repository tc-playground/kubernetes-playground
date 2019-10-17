#!/bin/bash

# Configuring kubectl for Remote Access ***************************************
#

# generate a kubeconfig file for the kubectl command line utility based on the 
# admin user credentials.

# Each kubeconfig requires a Kubernetes API Server to connect to. To support 
# high availability the IP address assigned to the external load balancer 
# fronting the Kubernetes API Servers will be used.

function configure-kubectl() {

  local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

  export KUBECONFIG="${dir}/admin.kubeconfig"

  local KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
    --region $(gcloud config get-value compute/region) \
    --format 'value(address)')

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context kubernetes-the-hard-way
}

function verify() {
  kubectl get componentstatuses
  kubectl get nodes
}

# Main ************************************************************************
#

# If provided, execute the specified function.
if [ ! -z "$1" ]; then
  $1
fi