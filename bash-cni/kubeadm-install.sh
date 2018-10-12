#!/bin/bash
sudo apt-get update
sudo apt-get install -y docker.io apt-transport-https curl jq nmap iproute2
sudo su
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat > /etc/apt/sources.list.d/kubernetes.list <<EOF2
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF2
