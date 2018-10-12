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

ID="${NW_NAME:-k8s}"

function create-infra() {
    echo "Creating infra..."

    # Networking --------------------------------------------------------------
    # 
    # Create nw with subnet in each region.
    # Create routes to direct traffic between subnets.
    # Create routes to direct external trafic to degault internet gateway.
    gcloud compute networks create "${ID}" --zone "${zone}" 

    gcloud compute firewall-rules create "${ID}-allow-all" \
        --zone "${zone}" \
        --network "${ID}" \
        --action allow \
        --direction ingress \
        --rules all \
        --source-ranges 0.0.0.0/0 \
        --priority 1000

    # Instances ---------------------------------------------------------------

    # Configure master with IP forwarding.
    gcloud compute instances create "${ID}-master" \
        --zone "${zone}" \
        --image-family ubuntu-1604-lts \
        --image-project ubuntu-os-cloud \
        --network "${ID}" \
        --can-ip-forward

    # Configure worker with IP forwarding.
    gcloud compute instances create "${ID}-worker" \
        --zone "${zone}" \
        --image-family ubuntu-1604-lts \
        --image-project ubuntu-os-cloud \
        --network k8s \
        --can-ip-forward
}

function delete-infra() {
    echo "Deleting infra..."
    gcloud compute instances delete "${ID}-worker"
    gcloud compute instances delete "${ID}-master"
    gcloud compute firewall-rules delete "${ID}-allow-all"
    gcloud compute networks delete "${ID}"  
}

function install-kubernetes() {
    # generate kubeadm installer
    # 
    generate-kubeadm-install

    # instal kubeadm - run on master node
    # 
    gcloud compute scp --zone "${zone}" kubeadm-install.sh "${ID}-master":./
    gcloud compute ssh --zone "${zone}" --zone "${zone}" --command ./kubeadm-install.sh
    echo "ssh to master node and run: "
    echo "sudo kubeadm init --pod-network-cidr=10.244.0.0/16"
    echo "mkdir -p $HOME/.kube"
    echo "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config"
    echo "sudo chown $(id -u):$(id -g) $HOME/.kube/config"
    echo "export KUBECONFIG=$HOME/.kube/config"
    echo "kubectl get nodes"

    # install kubeadm - run on worker nodes
    # 
    gcloud compute scp --zone "${zone}" kubeadm-install.sh "${ID}-worker":./
    gcloud compute ssh --zone "${zone}""${instance}" --command ./kubeadm-install.sh 
    echo "ssh to master node and run: "
    echo "execute ouput of 'kubeadm init' from master to join..."
}

function generate-kubeadm-install() {
      cat > kubeadm-install.sh <<EOF
#!/bin/bash
sudo apt-get update
sudo apt-get install -y docker.io apt-transport-https curl jq nmap iproute2
sudo su
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat > /etc/apt/sources.list.d/kubernetes.list <<EOF2
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF2
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

$@

