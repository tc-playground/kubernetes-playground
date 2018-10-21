#!/bin/bash

project=$(gcloud info | grep 'project' | cut -d "[" -f2 | cut -d "]" -f1)
region=$(gcloud info | grep 'region' | cut -d "[" -f2 | cut -d "]" -f1)
zone=$(gcloud info | grep 'zone' | cut -d "[" -f2 | cut -d "]" -f1)

echo "Project: ${project}"
echo "Region : ${region}"
echo "Zone   : ${zone}"

function get-gce-support() {
    curl -O https://raw.githubusercontent.com/templecloud/temos/master/environments/k8s-gke/gke.sh
    chmod u+rwx gke.sh
}

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
    # generate kubeadm installer
    # 
    # generate-kubeadm-install

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

function generate-kubeadm-install() {
      cat > kubeadm-install.sh <<EOF
#!/bin/bash

function install() {
    # Update and install utils.
    sudo apt-get update
    sudo apt-get install -y docker.io apt-transport-https curl jq nmap iproute2
    # Configure kubernetes apt repo.
    sudo bash -c "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"
    local kubernetes="deb http://apt.kubernetes.io/ kubernetes-xenial main"
    local apts="/etc/apt/sources.list"
    sudo bash -c "grep -q -F '${kubernetes}' ${apts} || echo ${kubernetes} >> ${apts}"
} && install
EOF
    chmod u+x kubeadm-install.sh 
}

function get-master-node-cidr() {
    local mn_cidr=$(kubectl get node "${ID}-master" -ojsonpath='{.spec.podCIDR}')
    echo "mn_cidr"
}

function get-worker-node-cidr() {
    local wn_cidr=$(kubectl get node "${ID}-worker}" -ojsonpath='{.spec.podCIDR}')
    echo "wn_cidr"
}


function ssh-master() {
    gcloud compute ssh --zone "${zone}" "${ID}-master"
}


function ssh-worker() {
    gcloud compute ssh --zone "${zone}" "${ID}-worker"
}

$@

