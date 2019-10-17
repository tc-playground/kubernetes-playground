#!/bin/bash

# Deploying the DNS Cluster Add-on ********************************************
#

# Deploy the DNS add-on which provides DNS based service discovery to 
# applications running inside the Kubernetes cluster.
#
# * https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
# * https://github.com/kubernetes/dns/blob/master/docs/specification.md

# Deploy the kube-dns cluster add-on:
function deploy-dns() {
  kubectl create -f https://storage.googleapis.com/kubernetes-the-hard-way/kube-dns.yaml
}

function undeploy-dns() {
  kubectl delete -f https://storage.googleapis.com/kubernetes-the-hard-way/kube-dns.yaml
}

function list-dns-pods() {
  kubectl get pods -l k8s-app=kube-dns -n kube-system
}

function verify-dns() {
  echo "verify dns..."
  echo "run busy box:"
  kubectl run busybox --image=busybox --command -- sleep 3600
  echo "verify busybox pod"
  kubectl get pods -l run=busybox
  echo "perform pod nslookup for 'kubernetes':"
  POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
  kubectl exec -it $POD_NAME -- nslookup kubernetes
  kubectl delete pod $POD_NAME
}


# Main ************************************************************************
#

function create-dns() {
  echo "create dns..."
  deploy-dns
  list-dns-pods
}

function delete-dns() {
  echo "delete dns..."
  undeploy-dns
}

# If provided, execute the specified function.
if [ ! -z "$1" ]; then
  $1
fi