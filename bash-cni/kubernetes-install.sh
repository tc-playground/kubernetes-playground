#!/bin/bash

export POD_NETWORK_CIDR="10.244.0.0/16"

function install() {
    # Initialise kubeadm.
    # sudo kubeadm config images pull
    sudo kubeadm init --pod-network-cidr="${POD_NETWORK_CIDR}"
    
    # Configure kubeconfig.
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    export KUBECONFIG=$HOME/.kube/config
    
    # Test kubectl connectivity.
    kubectl get nodes

} && install