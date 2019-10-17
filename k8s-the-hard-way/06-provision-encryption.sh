#!/bin/bash

# Generating the Data Encryption Config and Key *******************************
#

# Kubernetes stores a variety of data including cluster state, application 
# configurations, and secrets. Kubernetes supports the ability to encrypt cluster 
# data at rest.
#
# In this lab you will generate an encryption key and an encryption config 
# suitable for encrypting Kubernetes Secrets.
#
# * https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
# * https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#understanding-the-encryption-at-rest-configuration

# Provision Encryption Config *************************************************
#

function create-encryption-config() {
  echo "creating encryption config..."
  ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
  cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
}

function delete-encryption-config() {
  echo "deleting encryption config..."
  rm -f encryption-config.yaml
}

function deploy-controller-encryption-configs() {
  echo "deploying controller kubeconfigs..."
  for instance in controller-0 controller-1 controller-2; do
    echo "deploying ${instance} kubeconfig..."
    gcloud compute scp encryption-config.yaml ${instance}:~/
  done
}

# Encryption ******************************************************************
#

function create-encryption() {
  create-encryption-config
  deploy-controller-encryption-configs
}

function delete-encryption() {
  delete-encryption-config
}

# Main ************************************************************************
#

# If provided, execute the specified function.
if [ ! -z "$1" ]; then
  $1
fi