#!/bin/bash

# Provisioning a CA and Generating TLS Certificates ***************************
#

# Provision a PKI Infrastructure using CloudFlare's PKI toolkit, cfssl, then 
# use it to bootstrap a Certificate Authority, and generate TLS certificates 
# for the following components: 
#   * etcd
#   * kube-apiserver
#   * kube-controller-manager
#   * kube-scheduler
#   * kubelet
#   * kube-proxy

function check-prerequisites() {
  if [ -z "$(which cfssl)" ]; then
    echo "No 'cfssl' present on the path. Please install cfssl."
    exit 1
  fi
  if [ -z "$(which cfssljson)" ]; then
    echo "No 'cfssljson' present on the path. Please install cfssljson."
    exit 1
  fi
}

# Provision CA ****************************************************************
#

# Provision a Certificate Authority that can be used to generate additional 
# TLS certificates:
#   * CA configuration files
#   * certificate
#   * private key
#
function create-certificate-authority() {
  # Create ca-config.
  cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
  # Create ca-csr.
  cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF
  # Create certificates.
  cfssl gencert -initca ca-csr.json | cfssljson -bare ca
}


function delete-certificate-authority() {
  echo "deleting certificate authority certs"
  rm -f ca-key.pem ca.pem
  rm -f ca-csr.json ca.csr 
  rm -f ca-config.json 
}

# Provision Admin Client Certificates *****************************************
#

# Generate client and server certificates for each Kubernetes component and a 
# client certificate for the Kubernetes admin user.

function create-admin-certs() {
  # Generate config file
  cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
  # Generate the admin certificates and private key using CA.
  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    admin-csr.json | cfssljson -bare admin
}

function delete-admin-certs() {
  echo "deleting admin certs"
  rm -f admin-key.pem admin.pem  
  rm -f admin-csr.json admin.csr 
}

# Provision Kublet Client Certificates ****************************************
#

# Kubernetes uses a special-purpose authorization mode called Node Authorizer, 
# that specifically authorizes API requests made by Kubelets. In order to be 
# authorized by the Node Authorizer, Kubelets must use a credential that 
# identifies them as being in the system:nodes group, with a username of 
# system:node:<nodeName>. 
#
# Create a certificate for each Kubernetes worker node hat meets the Node 
# Authorizer requirements.
#
# * https://kubernetes.io/docs/reference/access-authn-authz/node/
# * https://kubernetes.io/docs/concepts/overview/components/#kubelet

function create-kubelet-certs() {
  for instance in worker-0 worker-1 worker-2; do
    cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

    EXTERNAL_IP=$(gcloud compute instances describe ${instance} \
      --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

    INTERNAL_IP=$(gcloud compute instances describe ${instance} \
      --format 'value(networkInterfaces[0].networkIP)')

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
      -profile=kubernetes \
      ${instance}-csr.json | cfssljson -bare ${instance}
  done
}

function delete-kubelet-certs() {
    echo "deleting kubelet certs"
  rm -f worker-*.pem worker-*-key.pem 
  rm -f worker-*-csr.json worker-*.csr
}

# Provision Kube Controller Manager Client Certificates ***********************
#

function create-kube-controller-manager-certs() {
  cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
}

function delete-kube-controller-manager-certs() {
  echo "deleting kube controller manager certs"
  rm -f kube-controller-manager-key.pem kube-controller-manager.pem
  rm -f kube-controller-manager-csr.json kube-controller-manager.csr
}

# Provision Kube Proxy Client Certificates ************************************
#

function create-kube-proxy-certs() {
  cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    kube-proxy-csr.json | cfssljson -bare kube-proxy
}

function delete-kube-proxy-certs() {
  echo "deleting kube proxy certs"
  rm -f kube-proxy-key.pem kube-proxy.pem
  rm -f kube-proxy-csr.json kube-proxy.csr
}

# Provision Kube Scheduler Client Certificates ********************************
#

function create-kube-scheduler-certs() {
  cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    kube-scheduler-csr.json | cfssljson -bare kube-scheduler
}

function delete-kube-scheduler-certs() {
  echo "deleting kube scheduler certs"
  rm -f kube-scheduler-key.pem kube-scheduler.pem
  rm -f kube-scheduler-csr.json kube-scheduler.csr
}


# Provision Kubernetes API Server Client Certificates *************************
#

# The kubernetes-the-hard-way static IP address will be included in the list of 
# subject alternative names for the Kubernetes API Server certificate. This will 
# ensure the certificate can be validated by remote clients.

function create-kube-api-server-certs() {
  KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

  cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
    -profile=kubernetes \
    kubernetes-csr.json | cfssljson -bare kubernetes
}

function delete-kube-api-server-certs() {
  echo "deleting kube api server certs"
  rm -f kubernetes-key.pem kubernetes.pem
  rm -f kubernetes-csr.json kubernetes.csr
}

# Provision Kubernetes Service Account Key Pair *******************************
#

# The Kubernetes Controller Manager leverages a key pair to generate and sign 
# service account tokens as describe in the managing service accounts 
# documentation.
#
# * https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/

function create-kube-service-acount-key-pair() {
  cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    service-account-csr.json | cfssljson -bare service-account
}

function delete-kube-service-acount-key-pair() {
  echo "deleting kube service account pair"
  rm -f service-account-csr.json service-account.csr
  rm -f service-account-key.pem service-account.pem
}

# Distribute the Client and Server Certificates *******************************
#

function deploy-controller-certificates() {
  for instance in controller-0 controller-1 controller-2; do
    echo "deploying controller certificates to instance ${instance}"
    gcloud compute scp --strict-host-key-checking=no \
      ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
      service-account-key.pem service-account.pem ${instance}:~/
  done
}

function deploy-worker-certificates() {
  for instance in worker-0 worker-1 worker-2; do
    echo "deploying worker certificates to instance ${instance}"
    gcloud compute scp --strict-host-key-checking=no \
    ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
  done
}

function deploy-certificates() {
  deploy-controller-certificates
  deploy-worker-certificates 
}

# Certificates ****************************************************************
#

function create-pki() {
  create-certificate-authority
  create-admin-certs 
  create-kubelet-certs 
  create-kube-controller-manager-certs
  create-kube-proxy-certs 
  create-kube-scheduler-certs
  create-kube-api-server-certs
  create-kube-service-acount-key-pair
  deploy-certificates
}

function delete-pki() {
  delete-kube-service-acount-key-pair
  delete-kube-api-server-certs
  delete-kube-scheduler-certs
  delete-kube-proxy-certs 
  delete-kube-controller-manager-certs
  delete-kubelet-certs
  delete-admin-certs
  delete-certificate-authority 
}

# Main ************************************************************************
#

# If provided, execute the specified function.
if [ ! -z "$1" ]; then
  $1
fi
