#!/bin/bash

function install() {
    # Initialise kubeadm.
    # sudo kubeadm config images pull
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16
    
    # Configure kubeconfig.
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    export KUBECONFIG=$HOME/.kube/config
    
    # Test kubectl connectivity.
    kubectl get nodes

} && install