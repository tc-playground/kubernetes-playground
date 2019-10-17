#!/bin/bash

# Bootstrapping the Kubernetes Worker Nodes ***********************************
#

# Bootstrap three Kubernetes worker nodes. 
#
# The following components will be installed on each node:
#
#   * runc: https://github.com/opencontainers/runc / https://www.opencontainers.org/
#   * gVisor: https://github.com/google/gvisor
#   * container networking plugins (CNI): https://github.com/containernetworking/cni
#   * containerd: https://github.com/containerd/containerd / https://containerd.io/
#   * kubelet: https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
#   * kube-proxy: https://kubernetes.io/docs/concepts/cluster-administration/proxies/


# Provision Worker Base *******************************************************
#

function _install-worker-base() {
  local instance=$1
  # Generate installation script.
  cat > install-worker-base.sh <<EOF
#!/bin/bash

# Provision Base-Tools ********************************************************
#

sudo apt-get update
# NB: The socat binary enables support for the kubectl port-forward command.
sudo apt-get -y install socat conntrack ipset

wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl

chmod +x kubectl
sudo cp kubectl /usr/local/bin/
EOF
  # Set permissions.
  chmod u+x install-worker-base.sh 
  # Upload install script.
  gcloud compute scp install-worker-base.sh "${instance}":./
  # Execute installation script.
  gcloud compute ssh "${instance}" --command ./install-worker-base.sh
}

function _uninstall-worker-base() {
  local instance=$1
  # Delete installation script.
  gcloud compute ssh "${instance}" --command 'sudo rm -f ./kubectl'
  gcloud compute ssh "${instance}" --command '/usr/local/bin/kubectl'
  gcloud compute ssh "${instance}" --command 'sudo apt-get -y uninstall socat conntrack ipset'
  # Delete local script.
  rm -f ./install-worker-base.sh
}

# Configure CNI Networking ****************************************************
#
function _install-cni-networking() {
  local instance=$1
  # Generate installation script.
  cat > install-cni-networking.sh <<EOF
#!/bin/bash

# Install CNI Networking ******************************************************
#

# Install CNI Networking.
#
wget -q --show-progress --https-only --timestamping \
  https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz
sudo mkdir -p /opt/cni/bin/
sudo mkdir -p /etc/cni/net.d
sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/

# Configure CNI Networking.
#

# Retrieve the Pod CIDR range for the current compute instance
POD_CIDR=\$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)

# Create the bridge network configuration file
cat <<EOF2 | sudo -E tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "\${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF2

# Create the loopback network configuration file:
cat <<EOF2 | sudo -E tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF2
EOF
  # Set permissions.
  chmod u+x install-cni-networking.sh 
  # Upload install script.
  gcloud compute scp install-cni-networking.sh "${instance}":./
  # Execute installation script.
  gcloud compute ssh "${instance}" --command ./install-cni-networking.sh
}

function _uninstall-cni-networking() {
  local instance=$1
  # Delete installation script.
  gcloud compute ssh "${instance}" --command 'sudo rm -f /etc/cni/net.d/99-loopback.conf'
  gcloud compute ssh "${instance}" --command 'sudo rm -f /etc/cni/net.d/10-bridge.conf'
  gcloud compute ssh "${instance}" --command 'sudo rm -f /opt/cni/bin/{bridge,dhcp,host-local,loopback,portmap,sample,vlan,flannel,ipvlan,macvlan,ptp,tuning}'
  gcloud compute ssh "${instance}" --command 'sudo rm -Rf /etc/cni/net.d'
  gcloud compute ssh "${instance}" --command 'sudo rm -f ./cni-plugins-amd64-v0.6.0.tgz'
  gcloud compute ssh "${instance}" --command 'sudo rm -f ./install-cni-networking.sh'
  # Delete local script.
  rm -f ./install-cni-networking.sh
}

# Configure containerd ********************************************************
#
function _install-cri-containerd() {
  local instance=$1
  # Generate installation script.
  cat > install-cri-containerd.sh <<EOF
#!/bin/bash

# Install containerd **********************************************************
#

# Download containerd binaries.
#
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-incubator/cri-tools/releases/download/v1.0.0-beta.0/crictl-v1.0.0-beta.0-linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-the-hard-way/runsc \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc5/runc.amd64 \
  https://github.com/containerd/containerd/releases/download/v1.1.0/containerd-1.1.0.linux-amd64.tar.gz


# Install containerd binaries.
#
sudo tar -xvf crictl-v1.0.0-beta.0-linux-amd64.tar.gz -C /usr/local/bin/
sudo mv runc.amd64 runc
chmod +x runc runsc
sudo cp runc runsc /usr/local/bin/
sudo tar -xvf containerd-1.1.0.linux-amd64.tar.gz -C /


# Configure Containerd.
#

sudo mkdir -p /etc/containerd/

# Untrusted workloads will be run using the runc runtime.
# Untrusted workloads will be run using the gVisor (runsc) runtime.
#
cat << EOF2 | sudo -E tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
EOF2

# Create containerd service file.
#
cat <<EOF2 | sudo -E tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF2
EOF
  # Set permissions.
  chmod u+x install-cri-containerd.sh 
  # Upload install script.
  gcloud compute scp install-cri-containerd.sh "${instance}":./
  # Execute installation script.
  gcloud compute ssh "${instance}" --command ./install-cri-containerd.sh
  # Start-up services.
  gcloud compute ssh "${instance}" --command "sudo systemctl daemon-reload"
  gcloud compute ssh "${instance}" --command "sudo systemctl enable containerd"
  gcloud compute ssh "${instance}" --command "sudo systemctl start containerd"
}

function _uninstall-cri-containerd() {
  local instance=$1
  # Shut-down services.
  gcloud compute ssh "${instance}" --command "sudo systemctl stop containerd"
  gcloud compute ssh "${instance}" --command "sudo systemctl disable containerd"
  gcloud compute ssh "${instance}" --command "sudo systemctl daemon-reload"
  # Delete installation script.
  gcloud compute ssh "${instance}" --command 'sudo rm -f /etc/systemd/system/containerd.service'
  gcloud compute ssh "${instance}" --command 'sudo rm -f /etc/containerd/config.toml'
  gcloud compute ssh "${instance}" --command 'sudo rm -Rf /etc/containerd'
  gcloud compute ssh "${instance}" --command 'sudo rm -f /bin/{containerd,containerd-release,containerd-shim,containerd-stress,ctr}'
  gcloud compute ssh "${instance}" --command 'sudo rm -f /usr/local/bin/{crictl,runc,runsc}'
  gcloud compute ssh "${instance}" --command 'sudo rm -f ./{runc,runsc}'
  gcloud compute ssh "${instance}" --command 'sudo rm -f ./containerd-1.1.0.linux-amd64.tar.gz'
  gcloud compute ssh "${instance}" --command 'sudo rm -f crictl-v1.0.0-beta.0-linux-amd64.tar.gz'
  gcloud compute ssh "${instance}" --command 'sudo rm -f ./install-cri-containerd.sh'
  # Delete local script.
  rm -f ./install-cni-containerd.sh
}


# Configure kubelet ***********************************************************
#

function _install-kubelet() {
  local instance=$1
  # Generate installation script.
  cat > install-kubelet.sh <<EOF
#!/bin/bash

# Install kubelet *************************************************************
#

# Download kubelet binaries.
#
wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubelet

# Install kubelet binaries.
#
chmod +x kubelet
sudo cp kubelet /usr/local/bin/

sudo mkdir -p /var/lib/kubelet/
sudo mkdir -p /var/lib/kubernetes/

sudo cp \${HOSTNAME}-key.pem \${HOSTNAME}.pem /var/lib/kubelet/
sudo cp \${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
sudo cp ca.pem /var/lib/kubernetes/

# Configure kubelet ***********************************************************
#

# Create the kubelet-config.yaml configuration file:
#
cat <<EOF2 | sudo -E tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "\${POD_CIDR}"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/\${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/\${HOSTNAME}-key.pem"
EOF2

# Create the kubelet.service systemd unit file:
#
cat <<EOF2 | sudo -E tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF2
EOF
  # Set permissions.
  chmod u+x install-kubelet.sh 
  # Upload install script.
  gcloud compute scp install-kubelet.sh "${instance}":./
  # Execute installation script.
  gcloud compute ssh "${instance}" --command ./install-kubelet.sh
  # Start-up services.
  gcloud compute ssh "${instance}" --command "sudo systemctl daemon-reload"
  gcloud compute ssh "${instance}" --command "sudo systemctl enable kubelet"
  gcloud compute ssh "${instance}" --command "sudo systemctl start kubelet"
}

function _uninstall-kubelet() {
  local instance=$1
  # Shut-down services.
  gcloud compute ssh "${instance}" --command "sudo systemctl stop kubelet"
  gcloud compute ssh "${instance}" --command "sudo systemctl disable kubelet"
  gcloud compute ssh "${instance}" --command "sudo systemctl daemon-reload"
  # Delete installation script.
  gcloud compute ssh "${instance}" --command 'sudo rm -f /etc/systemd/system/kubelet.service'
  gcloud compute ssh "${instance}" --command 'sudo rm -f /var/lib/kubelet/kubelet-config.yaml'
  gcloud compute ssh "${instance}" --command 'sudo rm -Rf /var/lib/kubelet'
  gcloud compute ssh "${instance}" --command 'sudo rm -f /usr/local/bin/kubelet'
  gcloud compute ssh "${instance}" --command 'sudo rm -f ./kubelet'
  gcloud compute ssh "${instance}" --command 'sudo rm -f ./install-kubelet.sh'
  # Delete local script.
  rm -f ./install-kubelet.sh
}


# Configure Kubernetes Proxy **************************************************
#

function _install-kube-proxy() {
  local instance=$1
  # Generate installation script.
  cat > install-kube-proxy.sh <<EOF
#!/bin/bash

# Install kube-proxy **********************************************************
#

# Download kube-proxy binaries.
#
wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-proxy

# Install kube-proxy binaries.
#
chmod +x kube-proxy
sudo cp kube-proxy /usr/local/bin/

sudo mkdir -p /var/lib/kube-proxy/
sudo cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

# Configure kube-proxy ********************************************************
#

# Create the kube-proxy-config.yaml configuration file:
#
cat <<EOF2 | sudo -E tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF2

# Create the kube-proxy.service systemd unit file:
#
cat <<EOF2 | sudo -E tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF2
EOF
  # Set permissions.
  chmod u+x install-kube-proxy.sh 
  # Upload install script.
  gcloud compute scp install-kube-proxy.sh "${instance}":./
  # Execute installation script.
  gcloud compute ssh "${instance}" --command ./install-kube-proxy.sh
  # Start-up services.
  gcloud compute ssh "${instance}" --command "sudo systemctl daemon-reload"
  gcloud compute ssh "${instance}" --command "sudo systemctl enable kube-proxy"
  gcloud compute ssh "${instance}" --command "sudo systemctl start kube-proxy"
}

function _uninstall-kube-proxy() {
  local instance=$1
  # Shut-down services.
  gcloud compute ssh "${instance}" --command "sudo systemctl stop kube-proxy"
  gcloud compute ssh "${instance}" --command "sudo systemctl disable kube-proxy"
  gcloud compute ssh "${instance}" --command "sudo systemctl daemon-reload"
  # Delete installation script.
  gcloud compute ssh "${instance}" --command 'sudo rm -f /etc/systemd/system/kube-proxy.service'
  gcloud compute ssh "${instance}" --command 'sudo rm -f /var/lib/kube-proxy/kube-proxy-config.yaml'
  gcloud compute ssh "${instance}" --command 'sudo rm -Rf /var/lib/kube-proxy'
  gcloud compute ssh "${instance}" --command 'sudo rm -f /usr/local/bin/kube-proxy'
  gcloud compute ssh "${instance}" --command 'sudo rm -f ./kubelet'
  gcloud compute ssh "${instance}" --command 'sudo rm -f ./install-kube-proxy.sh'
  # Delete local script.
  rm -f ./install-kube-proxy.sh
}



# Work Plane *****************************************************************
#

function _reload-work-plane() {
  local instance=$1
  # Start-up work services.
  gcloud compute ssh "${instance}" --command "sudo systemctl daemon-reload"
  gcloud compute ssh "${instance}" --command "sudo systemctl enable containerd kubelet kube-proxy"
  gcloud compute ssh "${instance}" --command "sudo systemctl start containerd kubelet kube-proxy"
}

function create-work-plane() {
  echo "creating work-plane..."
  for instance in worker-0 worker-1 worker-2; do
    echo "installing ${instance} install-worker-base..."
    _install-worker-base ${instance}
    echo "installing ${instance} cni-networking..."
    _install-cni-networking ${instance}
    echo "installing ${instance} cri-containerd..."
    _install-cri-containerd ${instance}
    echo "installing ${instance} kubelet..."
    _install-kubelet ${instance}
    echo "installing ${instance} kube-proxy..."
    _install-kube-proxy ${instance}
  done
}

function verify-work-plane() {
  echo "verify work-plane..."
  for instance in controller-0 controller-1 controller-2; do
    echo "verify ${instance} worker-plane..."
    gcloud compute ssh  ${instance} --command "kubectl get nodes --kubeconfig admin.kubeconfig" 
  done
}

function delete-work-plane() {
  echo "deleting work-plane..."
  for instance in worker-0 worker-1 worker-2; do
    echo "uninstalling ${instance} kube-proxy..."
    _uninstall-kube-proxy ${instance}
    echo "uninstallng ${instance} kubelet..."
    _uninstall-kubelet ${instance}
    echo "uninstalling ${instance} cri-containerd..."
    _uninstall-cri-containerd ${instance}
    echo "uninstalling ${instance} cni-networking..."
    _uninstall-cni-networking ${instance}
  done
}

# Main ************************************************************************
#

# If provided, execute the specified function.
if [ ! -z "$1" ]; then
  $1
fi
