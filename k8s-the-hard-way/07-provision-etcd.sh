#!/bin/bash

# Bootstrapping the etcd Cluster **********************************************
#

# Kubernetes components are stateless and store cluster state in etcd. In this 
# lab you will bootstrap a three node etcd cluster and configure it for high 
# availability and secure remote access.
#
# * https://github.com/coreos/etcd

# Download and Install the etcd Binaries **************************************
#

function _install-etcd() {
  local instance=$1
  # Generate etcd installation script.
  cat > install-etcd.sh <<EOF
#!/bin/bash

# Download etcd binaries.
#
wget -q --show-progress --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/v3.3.5/etcd-v3.3.5-linux-amd64.tar.gz"

# Extract etcd and etcdctl.
#
tar -xvf etcd-v3.3.5-linux-amd64.tar.gz
sudo mv etcd-v3.3.5-linux-amd64/etcd* /usr/local/bin/

# Configure etcd keys.
#
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/

# The instance internal IP address will be used to serve client requests and 
# communicate with  etcd cluster peers. Retrieve the internal IP address for 
# the current compute instance:
#
INTERNAL_IP=\$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

# Each etcd member must have a unique name within an etcd cluster. Set the etcd 
# name to match the hostname of the current compute instance:
#
ETCD_NAME=\$(hostname -s)

# Create the etcd.service systemd unit file:
#
# cat > etcd.service <<EOF2
cat <<EOF2 | sudo -E tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name \${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://\${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://\${INTERNAL_IP}:2380 \\
  --listen-client-urls https://\${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://\${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF2
EOF

  # Set permissions.
  chmod u+x install-etcd.sh 

  # Upload install script.
  gcloud compute scp install-etcd.sh "${instance}":install-etcd.sh

  # Execute installation script.
  gcloud compute ssh "${instance}" --command ./install-etcd.sh

  # Start-up etcd.
  gcloud compute ssh "${instance}" --command "sudo systemctl daemon-reload"
  gcloud compute ssh "${instance}" --command "sudo systemctl enable etcd"
  gcloud compute ssh "${instance}" --command "sudo systemctl start etcd"
}

function create-etcd-control-plane() {
  echo "creating etcd control-plane"
  for instance in controller-0 controller-1 controller-2; do
    echo "installing ${instance} etcd service..."
    _install-etcd ${instance}
  done
}

function _uninstall-etcd() {
  local instance=$1
  # Shut-down etcd.
  gcloud compute ssh "${instance}" --command "sudo systemctl stop etcd"
  gcloud compute ssh "${instance}" --command "sudo systemctl disable etcd"
  gcloud compute ssh "${instance}" --command "sudo systemctl daemon-reload"
  # Clean up etcd resources.
  gcloud compute ssh "${instance}" --command "sudo rm -f /etc/systemd/system/etcd.service" 
  gcloud compute ssh "${instance}" --command "sudo rm -f /etc/etcd/{ca.pem,kubernetes-key.pem,kubernetes.pem}" 
  gcloud compute ssh "${instance}" --command "sudo rm -Rf /etc/etcd /var/lib/etcd"
  gcloud compute ssh "${instance}" --command "sudo rm -f /usr/local/bin/{etcd,etcdctl}"
  gcloud compute ssh "${instance}" --command "sudo rm -Rf etcd-v3.3.5-linux-amd64"
  gcloud compute ssh "${instance}" --command "sudo rm -f etcd-v3.3.5-linux-amd64.tar.gz"
  gcloud compute ssh "${instance}" --command "sudo rm -f install-etcd.sh"
  # Clean-up local
  rm -f install-etcd.sh
}

function delete-etcd-control-plane() {
  echo "delete etcd control-plane..."
  for instance in controller-0 controller-1 controller-2; do
    echo "uninstalling ${instance} etcd service..."
    _uninstall-etcd ${instance}
  done
}

function verify-etcd() {
  local env=" ETCDCTL_API=3"
  local cmd=" etcdctl member list"
  local endpoint="--endpoints=https://127.0.0.1:2379"
  local cacert="--cacert=/etc/etcd/ca.pem "
  local cert="--cert=/etc/etcd/kubernetes.pem"
  local key="--key=/etc/etcd/kubernetes-key.pem"

  echo "verify etcd control-plane..."
  for instance in controller-0 controller-1 controller-2; do
    echo "verify ${instance} etcd service..."
    gcloud compute ssh "${instance}" --command "sudo ${env} ${cmd} ${endpoint} ${cacert} ${cert} ${key}"
  done
}

# Etcd ************************************************************************
#

function create-etcd() {
  create-etcd-control-plane
}

function delete-etcd() {
  delete-etcd-control-plane
}

# Main ************************************************************************
#

# If provided, execute the specified function.
if [ ! -z "$1" ]; then
  $1
fi