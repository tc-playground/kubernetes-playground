#!/bin/bash

# Tools 
# 
# CIDR Calculator : https://www.ipaddressguide.com/cidr


project=$(gcloud info | grep 'project' | cut -d "[" -f2 | cut -d "]" -f1)
region=$(gcloud info | grep 'region' | cut -d "[" -f2 | cut -d "]" -f1)
zone=$(gcloud info | grep 'zone' | cut -d "[" -f2 | cut -d "]" -f1)


ID="k8s"
# MACHINE_TYPE="f1-micro"
MACHINE_TYPE="g1-small"

function create-infra() {
    echo "Creating infra..."

    # Networking --------------------------------------------------------------
    # 
    # Create nw with subnet in each region.
    # Create routes to direct traffic between subnets.
    # Create routes to direct external trafic to degault internet gateway.
    
    echo "Create VCN."
    gcloud compute networks create "${ID}-vcn"

    echo "Create firewall-rules."
    gcloud compute firewall-rules create "${ID}-allow-all" \
        --network "${ID}-vcn" \
        --action allow \
        --direction ingress \
        --rules all \
        --source-ranges 0.0.0.0/0 \
        --priority 1000

    # Instances ---------------------------------------------------------------

    # Configure master with IP forwarding.
    echo "Create master instance."
    gcloud compute instances create "${ID}-master" \
        --zone "${zone}" \
        --machine-type "${MACHINE_TYPE}" \
        --image-project ubuntu-os-cloud \
        --image-family ubuntu-1604-lts \
        --network "${ID}-vcn" \
        --can-ip-forward

    # Configure worker with IP forwarding.
    echo "Create worker instance."
    gcloud compute instances create "${ID}-worker" \
        --zone "${zone}" \
        --machine-type "${MACHINE_TYPE}" \
        --image-project ubuntu-os-cloud \
        --image-family ubuntu-1604-lts \
        --network "${ID}-vcn" \
        --can-ip-forward
}

function delete-infra() {
    echo "Deleting infra..."
    gcloud -q compute instances delete "${ID}-worker"
    gcloud -q compute instances delete "${ID}-master"
    gcloud -q compute firewall-rules delete "${ID}-allow-all"
    gcloud -q compute networks delete "${ID}-vcn"  
}

function install-kubernetes() {
    # Install kubeadm - on master node and initialise.
    # 
    gcloud compute scp --zone "${zone}" kubeadm-install.sh "${ID}-master":./
    gcloud compute ssh --zone "${zone}" "${ID}-master" --command ./kubeadm-install.sh

    gcloud compute scp --zone "${zone}" kubernetes-install.sh "${ID}-master":./
    gcloud compute ssh --zone "${zone}" "${ID}-master" --command ./kubernetes-install.sh

    local join_cmd=$(gcloud compute ssh --zone "${zone}" "${ID}-master" --command 'sudo kubeadm token create --print-join-command') 


    # Install kubeadm - on worker nodes and join to master.
    # 
    gcloud compute scp --zone "${zone}" kubeadm-install.sh "${ID}-worker":./
    gcloud compute ssh --zone "${zone}" "${ID}-worker" --command ./kubeadm-install.sh

    gcloud compute ssh --zone "${zone}" "${ID}-worker" --command "sudo ${join_cmd}"

    # Check cluster node status
    # 
    gcloud compute ssh --zone "${zone}" "${ID}-master" --command "kubectl get nodes"
}

function install-cni-config() {
    local cni_dir="/etc/cni/net.d/"

    # install on master - TODO: generate file.
    gcloud compute ssh --zone "${zone}" "${ID}-master" --command "sudo mkdir -p ${cni_dir}"
    gcloud compute scp --zone "${zone}" cni-master-config.json "${ID}-master":.
    gcloud compute ssh --zone "${zone}" "${ID}-master" --command "sudo mv cni-master-config.json ${cni_dir}"

    # install on worker - TODO: generate file.
    gcloud compute ssh --zone "${zone}" "${ID}-worker" --command "sudo mkdir -p ${cni_dir}"
    gcloud compute scp --zone "${zone}" cni-worker-config.json "${ID}-worker":.
    gcloud compute ssh --zone "${zone}" "${ID}-worker" --command "sudo mv cni-worker-config.json ${cni_dir}"
}


function create-nw-bridge() {
    local name=${1:-"cni0"}

    local master_bridge_ip="10.244.0.1/24"
    gcloud compute ssh --zone "${zone}" "${ID}-master" --command "sudo apt install -y bridge-utils"
    gcloud compute ssh --zone "${zone}" "${ID}-master" --command "sudo brctl addbr ${name}"
    # gcloud compute ssh --zone "${zone}" "${ID}-master" --command "ip link add name ${name} type bridge"
    gcloud compute ssh --zone "${zone}" "${ID}-master" --command "sudo ip link set ${name} up"
    gcloud compute ssh --zone "${zone}" "${ID}-master" --command "sudo ip addr add ${master_bridge_ip} dev ${name}"

    local worker_bridge_ip="10.244.1.1/24"
    gcloud compute ssh --zone "${zone}" "${ID}-worker" --command "sudo apt install -y bridge-utils"
    gcloud compute ssh --zone "${zone}" "${ID}-worker" --command "sudo brctl addbr ${name}"
    # gcloud compute ssh --zone "${zone}" "${ID}-worker" --command "ip link add name ${name} type bridge"
    gcloud compute ssh --zone "${zone}" "${ID}-worker" --command "sudo ip link set ${name} up"
    gcloud compute ssh --zone "${zone}" "${ID}-worker" --command "sudo ip addr add ${worker_bridge_ip} dev ${name}"
}


function get-node-pod-cidr() {
    local node=${1:-"master"}
    local node_pod_cidr=$(kubectl get node "${ID}-${node}" -ojsonpath='{.spec.podCIDR}')
    echo "${node_pod_cidr}"
}

# 2-node cluster pod cluster cidr '10.244.0.0/16' => 10.244.0.0/24
# Allows 256 nodes in cluster.
# Allows 256 pods on node.
function get-master-node-cidr() {
    local mn_cidr=$(get-node-pod-cidr)
    echo "${mn_cidr}"
}

# 2-node cluster pod cluster cidr '10.244.0.0/16' => 10.244.1.0/24
# Allows 256 nodes in cluster.
# Allows 256 pods on node.
function get-worker-node-cidr() {
    local mn_cidr=$(get-node-pod-cidr worker)
    echo "${mn_cidr}"
}

function ls-k8s-node-manifests() {
    local node=${1:-"master"}
    gcloud compute ssh --zone "${zone}" "${ID}-${node}" --command "ls /etc/kubernetes/manifests"
}

function ssh-master() {
    gcloud compute ssh --zone "${zone}" "${ID}-master"
}

function ssh-worker() {
    gcloud compute ssh --zone "${zone}" "${ID}-worker"
}

function kubectl() {
    local cmd=$@
    gcloud compute ssh --zone "${zone}" "${ID}-master" --command "kubectl ${cmd}"
}

function gke-env() {
    echo "Project: ${project}"
    echo "Region : ${region}"
    echo "Zone   : ${zone}"
}

function get-gce-support() {
    curl -O https://raw.githubusercontent.com/templecloud/temos/master/environments/k8s-gke/gke.sh
    chmod u+rwx gke.sh
}

$@

