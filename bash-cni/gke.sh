#/!bin/bash

# Environment variables.
#
# account=<google account e-mail>
# project=<gcloud project id>
# zone=<gcloud zone>
# ssh_key=<gcloud private key>
# username=<user name>

project=$(gcloud info | grep 'project' | cut -d "[" -f2 | cut -d "]" -f1)
region=$(gcloud info | grep 'region' | cut -d "[" -f2 | cut -d "]" -f1)
zone=$(gcloud info | grep 'zone' | cut -d "[" -f2 | cut -d "]" -f1)

cluster_name="trjl-gke-k8s-cluster"
machine_type="f1-micro"
num_nodes="3"

function gcloud-login() {
	# https://cloud.google.com/sdk/gcloud/reference/auth/login
	gcloud auth login ${account}
}

function create-cluster() {
	# https://cloud.google.com/sdk/gcloud/reference/container/clusters/create
	gcloud container clusters create ${cluster_name} --machine-type ${machine_type} --num-nodes ${num_nodes}
	# https://cloud.google.com/sdk/gcloud/reference/container/clusters/get-credentials
	gcloud container clusters get-credentials ${cluster_name}
	# GKE console
	echo "GKE console: https://console.cloud.google.com/home/dashboard"
}


function destroy-cluster() {
	# https://cloud.google.com/sdk/gcloud/reference/auth/login
	gcloud auth login ${account}
	# https://cloud.google.com/sdk/gcloud/reference/container/clusters/create
	gcloud container clusters delete ${cluster_name} --async
}


function describe-cluster() {
	# https://cloud.google.com/sdk/gcloud/reference/container/clusters/describe
	gcloud container clusters describe ${cluster_name}
}


function configure-kubectl() {
	# https://cloud.google.com/sdk/gcloud/reference/container/clusters/get-credentials
	gcloud container clusters get-credentials ${cluster_name} --project ${project} --zone ${zone}
}


function use-cluster() {
	kubectl config use-context gke_${project}_${region}_${cluster_name}
}

function hello() {
	echo "heello"
}


function proxy-cluster() {
	kubectl proxy
}

# get-nodes:
# 	kubectl get nodes -o wide


# ssh-node:
# 	ssh -i ${ssh-key} ${user_name}@${ip_address}


# ssh-instance:
# 	gcloud compute ssh ${instance_name}

if [ ! -z "$1" ]; then 
    $@
fi