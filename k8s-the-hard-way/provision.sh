#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${DIR}/03-provision-infra.sh" ""
source "${DIR}/04-provision-pki.sh" ""
source "${DIR}/05-provision-kubeconfigs.sh" ""
source "${DIR}/06-provision-encryption.sh" ""
source "${DIR}/07-provision-etcd.sh" ""
source "${DIR}/08-provision-control-plane.sh" ""
source "${DIR}/09-provision-work-plane.sh" ""
source "${DIR}/10-provision-remote-access-kubectl.sh" ""
source "${DIR}/11-provision-pod-network-routes.sh" ""
source "${DIR}/12-provision-dns.sh" ""

# K8s Cluster *****************************************************************
#
function create-k8s() {
  create-infra
  create-pki
  create-kubeconfigs
  create-encryption
  create-etcd
  create-control-plane
  create-work-plane
  configure-kubectl
  verify
  create-pod-network-routes
  create-dns
}

function delete-k8s() {
  delete-dns
  delete-pod-network-routes
  delete-work-plane
  delete-control-plane
  delete-etcd
  delete-encryption
  delete-kubeconfigs
  delete-pki
  delete-infra
}

# Main ************************************************************************
#

# If provided, execute the specified function.
if [ ! -z "$1" ]; then
  $1
fi