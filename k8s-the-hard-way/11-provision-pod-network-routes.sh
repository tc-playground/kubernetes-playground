#!/bin/bash

# Provision Pod Network Routes ************************************************
#

# Pods scheduled to a node receive an IP address from the node's Pod CIDR range. 
# At this point pods can not communicate with other pods running on different 
# nodes due to missing network routes.
#
# In this lab you will create a route for each worker node that maps the node's 
# Pod CIDR range to the node's internal IP address.
#
# There are other ways to implement the Kubernetes networking model.
#   * https://kubernetes.io/docs/concepts/cluster-administration/networking/#how-to-achieve-this
#   * https://tools.ietf.org/html/rfc1918
#

# The Routing Table ***********************************************************
#


# In this section you will gather the information required to create routes in 
# the kubernetes-the-hard-way VPC network.
#
# Print the internal IP address and Pod CIDR range for each worker instance:
function list-worker-instance-internal-pod-ip-and-cidr-range() {
  echo "list worker instance internal ip and pod cidr ranges:"
  for instance in worker-0 worker-1 worker-2; do
    echo "instance '${instance}' internal ip and pod cidr range:"
    gcloud compute instances describe ${instance} \
      --format 'value[separator=" "](networkInterfaces[0].networkIP,metadata.items[0].value)'
  done
}

# Routes
#
# Create network routes for each worker instance:

function create-worker-instance-pod-network-routes() {
  echo "creating worker instance pod network routes"
  for i in 0 1 2; do
    gcloud compute routes create kubernetes-route-10-200-${i}-0-24 \
      --network kubernetes-the-hard-way \
      --next-hop-address 10.240.0.2${i} \
      --destination-range 10.200.${i}.0/24
  done
}

function delete-worker-instance-pod-network-routes() {
  echo "deleting worker instance pod network routes"
  for i in 0 1 2; do
    gcloud compute routes delete -q kubernetes-route-10-200-${i}-0-24
  done
}

# List the routes in the kubernetes-the-hard-way VPC network:
function list-vpc-network-routes() {
  echo "list VPC network routes"
  gcloud compute routes list --filter "network: kubernetes-the-hard-way"
}


# Main ************************************************************************
#

function create-pod-network-routes() {
  list-worker-instance-internal-pod-ip-and-cidr-range
  create-worker-instance-pod-network-routes
  list-vpc-network-routes
}

function delete-pod-network-routes() {
  delete-worker-instance-pod-network-routes 
}

# If provided, execute the specified function.
if [ ! -z "$1" ]; then
  $1
fi