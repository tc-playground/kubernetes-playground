#!/bin/bash

# Generating Kubernetes Configuration Files for Authentication ****************
#

# Generate Kubernetes configuration files, also known as kubeconfigs, which 
# enable Kubernetes clients to locate and authenticate to the Kubernetes API 
# Servers.
#
# * https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/

# Generate kubeconfig files for: 
#   * controller manager clients
#   * kubelet clients
#   * kube-proxy clients
#   * scheduler clients
#   * admin user.

# Kubernetes Public IP Address ************************************************
#
# Each kubeconfig requires a Kubernetes API Server to connect to. To support 
# high availability the IP address assigned to the external load balancer 
# fronting the Kubernetes API Servers will be used.

function create-k8s-public-ip() {
  export KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
    --region $(gcloud config get-value compute/region) \
    --format 'value(address)')
}

function delete-k8s-public-ip() {
  unset KUBERNETES_PUBLIC_ADDRESS
}

# Provision Worker Node kubeconfig ********************************************
#

# When generating kubeconfig files for Kubelets the client certificate 
# matching  the Kubelet's node name must be used. This will ensure 
# Kubelets are properly authorized by the Kubernetes Node Authorizer.
#
# * https://kubernetes.io/docs/reference/access-authn-authz/node/

function create-worker-node-kubeconfigs() {
  echo "creating worker node kubeconfigs..."
  for instance in worker-0 worker-1 worker-2; do
    kubectl config set-cluster kubernetes-the-hard-way \
      --certificate-authority=ca.pem \
      --embed-certs=true \
      --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
      --kubeconfig=${instance}.kubeconfig

    kubectl config set-credentials system:node:${instance} \
      --client-certificate=${instance}.pem \
      --client-key=${instance}-key.pem \
      --embed-certs=true \
      --kubeconfig=${instance}.kubeconfig

    kubectl config set-context default \
      --cluster=kubernetes-the-hard-way \
      --user=system:node:${instance} \
      --kubeconfig=${instance}.kubeconfig

    kubectl config use-context default --kubeconfig=${instance}.kubeconfig
  done
}

function delete-worker-node-kubeconfigs() {
    echo "deleting worker node kubeconfigs..."
  rm -f worker-0.kubeconfig worker-1.kubeconfig worker-2.kubeconfig
}

# Provision Kube Proxy kubeconfig *********************************************
#

function create-kube-proxy-kubeconfig() {
    echo "creating kube-proxy kubeconfig..."
    kubectl config set-cluster kubernetes-the-hard-way \
      --certificate-authority=ca.pem \
      --embed-certs=true \
      --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
      --kubeconfig=kube-proxy.kubeconfig

    kubectl config set-credentials system:kube-proxy \
      --client-certificate=kube-proxy.pem \
      --client-key=kube-proxy-key.pem \
      --embed-certs=true \
      --kubeconfig=kube-proxy.kubeconfig

    kubectl config set-context default \
      --cluster=kubernetes-the-hard-way \
      --user=system:kube-proxy \
      --kubeconfig=kube-proxy.kubeconfig

    kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}

function delete-kube-proxy-kubeconfig() {
   echo "deleting kube-proxy kubeconfig..."
  rm -f kube-proxy.kubeconfig
}

# Provision Kube Controller Manager kubeconfig ********************************
#

function create-kube-controller-manager-kubeconfig() {
  echo "creating kube-controller-manager kubeconfig..."
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
}

function delete-kube-controller-manager-kubeconfig() {
  echo "deleting kube-controller-manager kubeconfig..."
  rm -f kube-controller-manager.kubeconfig
}

# Provision Kube Scheduler kubeconfig *****************************************
#

function create-kube-scheduler-kubeconfig() {
  echo "creating kube-scheduler kubeconfig..."
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
}

function delete-kube-scheduler-kubeconfig() {
  echo "deleting kube-scheduler kubeconfig..."
  rm -f kube-scheduler.kubeconfig
}

# Provision admin user kubeconfig *********************************************
#

function create-admin-kubeconfig() {
  echo "create admin kubeconfig..."
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig
}

function delete-admin-kubeconfig() {
  echo "deleting admin kubeconfig..."
  rm -f admin.kubeconfig
}

# Distribute the configurations ***********************************************
#

# Copy the appropriate kube-controller-manager and kube-scheduler kubeconfig 
# files to each controller instance
function deploy-controller-kubeconfigs() {
  echo "deploying controller kubeconfigs..."
  for instance in controller-0 controller-1 controller-2; do
    echo "deploying ${instance} kubeconfig..."
    gcloud compute scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${instance}:~/
  done
}

# Copy the appropriate kubelet and kube-proxy kubeconfig files to each worker instance.
function deploy-worker-kubeconfigs() {
  echo "deploying worker kubeconfigs..."
  for instance in worker-0 worker-1 worker-2; do
    echo "deploying ${instance} kubeconfig..."
    gcloud compute scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
  done
}

function deploy-kubeconfigs() {
  deploy-controller-kubeconfigs
  deploy-worker-kubeconfigs
}

# Configurations **************************************************************
#

function create-kubeconfigs() {
  create-k8s-public-ip
  create-worker-node-kubeconfigs
  create-kube-proxy-kubeconfig
  create-kube-controller-manager-kubeconfig
  create-kube-scheduler-kubeconfig
  create-admin-kubeconfig
  deploy-kubeconfigs
}

function delete-kubeconfigs() {
  delete-admin-kubeconfig
  delete-kube-scheduler-kubeconfig
  delete-kube-controller-manager-kubeconfig
  delete-kube-proxy-kubeconfig
  delete-worker-node-kubeconfigs
  delete-k8s-public-ip
}

# Main ************************************************************************
#

# If provided, execute the specified function.
if [ ! -z "$1" ]; then
  $1
fi