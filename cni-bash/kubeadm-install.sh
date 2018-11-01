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

    # Install kubeadm
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    
} && install


