#!/bin/bash

# Smoke Tests *****************************************************************
#
# A series of tasks to ensure your Kubernetes cluster is functioning correctly.


# Test Data Encryption at rest ************************************************
#
# * https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted
#

function test-data-encryption() {
  # Create secret.
  kubectl create secret generic kubernetes-the-hard-way \
    --from-literal="mykey=mydata"
  
  # Get hexdump of secret from etcd.
  gcloud compute ssh controller-0 \
    --command "sudo ETCDCTL_API=3 etcdctl get \
      --endpoints=https://127.0.0.1:2379 \
      --cacert=/etc/etcd/ca.pem \
      --cert=/etc/etcd/kubernetes.pem \
      --key=/etc/etcd/kubernetes-key.pem\
      /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"

  # Expected result.
  # 00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
  # 00000010  73 2f 64 65 66 61 75 6c  74 2f 6b 75 62 65 72 6e  |s/default/kubern|
  # 00000020  65 74 65 73 2d 74 68 65  2d 68 61 72 64 2d 77 61  |etes-the-hard-wa|
  # 00000030  79 0a 6b 38 73 3a 65 6e  63 3a 61 65 73 63 62 63  |y.k8s:enc:aescbc|
  # 00000040  3a 76 31 3a 6b 65 79 31  3a 6f 75 27 dd 26 e5 37  |:v1:key1:ou'.&.7|
  # 00000050  4c 70 c4 f2 1a 9b f2 5c  6b e8 dc a1 a7 69 60 7c  |Lp.....\k....i`||
  # 00000060  b9 f4 a2 7d 8f 7a ed db  d9 b1 cc 08 30 59 f8 c7  |...}.z......0Y..|
  # 00000070  01 b6 30 10 fc 25 77 32  e2 e7 a8 2f 50 5d 79 71  |..0..%w2.../P]yq|
  # 00000080  d8 af 6b 2a 49 ad d4 4a  c2 7d f6 66 9a c0 21 31  |..k*I..J.}.f..!1|
  # 00000090  9f 02 87 49 d2 c9 2f e2  a9 d5 92 87 c4 78 e8 6c  |...I../......x.l|
  # 000000a0  a8 b7 69 5f 5d 03 eb 1e  01 43 79 dd 1c 7d 78 ce  |..i_]....Cy..}x.|
  # 000000b0  14 f4 0f d7 94 d7 67 16  66 a3 dd db 35 53 d2 5d  |......g.f...5S.]|
  # 000000c0  8a 42 7c d9 13 8c 35 20  a5 a3 0f e5 05 ac cc 25  |.B|...5 .......%|
  # 000000d0  15 79 28 da 82 76 ba 3d  c9 49 05 b3 b9 07 e6 96  |.y(..v.=.I......|
  # 000000e0  84 fc 21 35 97 b9 26 98  d7 0a                    |..!5..&...|
  # 000000ea

  # The etcd key should be prefixed with k8s:enc:aescbc:v1:key1, which indicates 
  # the aescbc provider was used to encrypt the data with the key1 encryption key.
}


# Test Deployments (nginx) ****************************************************
#
# * https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
# * https://nginx.org/en/

function test-nginx-deployment() {
  # Create nginx deployment
  kubectl run nginx --image=nginx

  # Poll for nginx pod.
  kubectl get pods -l run=nginx

  # Expected result. 
  # NAME                     READY     STATUS    RESTARTS   AGE
  # nginx-65899c769f-xkfcn   1/1       Running   0          15s
}


# Test Port Forwarding ********************************************************
#
# * https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/

function test-nginx-deployment-portforward() {
  # Get name of nginx pod.
  local POD_NAME=$(kubectl get pods -l run=nginx -o jsonpath="{.items[0].metadata.name}")

  # Forward port 8080 on your local machine to port 80 of the nginx pod.
  kubectl port-forward $POD_NAME 8080:80

  # Expected result. 
  # Forwarding from 127.0.0.1:8080 -> 80
  # Forwarding from [::1]:8080 -> 80

  # In a new terminal make an HTTP request using the forwarding address:
  curl --head http://127.0.0.1:8080

  # Expected result.
  # HTTP/1.1 200 OK
  # Server: nginx/1.13.12
  # Date: Mon, 14 May 2018 13:59:21 GMT
  # Content-Type: text/html
  # Content-Length: 612
  # Last-Modified: Mon, 09 Apr 2018 16:01:09 GMT
  # Connection: keep-alive
  # ETag: "5acb8e45-264"
  # Accept-Ranges: bytes
}


# Test Log Retrieval *************************************************************
#
# * https://kubernetes.io/docs/concepts/cluster-administration/logging/

function test-nginx-deployment-pod-log() {
  # Get name of nginx pod.
  local POD_NAME=$(kubectl get pods -l run=nginx -o jsonpath="{.items[0].metadata.name}")

  # Get logs.
  kubectl logs $POD_NAME

  # Expected result.
  # 127.0.0.1 - - [17/Jun/2018:22:43:25 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.43.0" "-"
}


# Test Pod Exec ***************************************************************
#
# * https://kubernetes.io/docs/tasks/debug-application-cluster/get-shell-running-container/#running-individual-commands-in-a-container

function test-nginx-deployment-pod-exec() {
  # Get name of nginx pod.
  local POD_NAME=$(kubectl get pods -l run=nginx -o jsonpath="{.items[0].metadata.name}")

  # Print the nginx version by executing the nginx -v command in the nginx container.
  kubectl exec -ti $POD_NAME -- nginx -v

  # Expected result.
  # nginx version: nginx/1.13.12
}


# Test NodePort Service *******************************************************
#
# Verify the ability to expose applications using a Service.
#
# * https://kubernetes.io/docs/concepts/services-networking/service/
# * https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport
# * https://kubernetes.io/docs/setup/scratch/#cloud-provider

function test-nginx-deployment-nodeport-service() {

  # Expose the nginx deployment using a NodePort service.
  kubectl expose deployment nginx --port 80 --type NodePort

  # Get name of nginx pod.
  local POD_NAME=$(kubectl get pods -l run=nginx -o jsonpath="{.items[0].metadata.name}")

  # Retrieve the node port assigned to the nginx service.
  local NODE_PORT=$(kubectl get svc nginx \
    --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
  
  # Create a firewall rule that allows remote access to the nginx node port.
  # NB: Linter idea...
  gcloud compute firewall-rules create kubernetes-the-hard-way-allow-nginx-service \
    --allow=tcp:${NODE_PORT} \
    --network kubernetes-the-hard-way
  
  # Retrieve the external IP address of a worker instance.
  local EXTERNAL_IP=$(gcloud compute instances describe worker-0 \
    --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

  # Make an HTTP request using the external IP address and the nginx node port.
  curl -I http://${EXTERNAL_IP}:${NODE_PORT}

  # Expected result.
  # HTTP/1.1 200 OK
  # Server: nginx/1.15.0
  # Date: Sun, 17 Jun 2018 23:08:38 GMT
  # Content-Type: text/html
  # Content-Length: 612
  # Last-Modified: Tue, 05 Jun 2018 12:00:18 GMT
  # Connection: keep-alive
  # ETag: "5b167b52-264"
  # Accept-Ranges: bytes
}


# Test Untrusted Service ******************************************************
#
# Verify the ability to run untrusted workloads using gVisor.
#
# * https://github.com/google/gvisor

function test-nginx-deployment-pod-exec() {
  # Create an untrusted pod.
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: untrusted
  annotations:
    io.kubernetes.cri.untrusted-workload: "true"
spec:
  containers:
    - name: webserver
      image: gcr.io/hightowerlabs/helloworld:2.0.0
EOF

  # Verify the untrusted pod is running under gVisor (runsc) by inspecting the assigned worker node.
  kubectl get pods -o wide

  # Get the node name where the untrusted pod is running.
  local INSTANCE_NAME=$(kubectl get pod untrusted --output=jsonpath='{.spec.nodeName}')

  # SSH into the worker node.
  gcloud compute ssh ${INSTANCE_NAME}

  # List the containers running under gVisor.
  sudo runsc --root  /run/containerd/runsc/k8s.io list
  # Expected result.
  # I0617 23:17:14.192931    8871 x:0] ***************************
  # I0617 23:17:14.193267    8871 x:0] Args: [runsc --root /run/containerd/runsc/k8s.io list]
  # I0617 23:17:14.193344    8871 x:0] Git Revision: 08879266fef3a67fac1a77f1ea133c3ac75759dd
  # I0617 23:17:14.193391    8871 x:0] PID: 8871
  # I0617 23:17:14.193436    8871 x:0] UID: 0, GID: 0
  # I0617 23:17:14.193473    8871 x:0] Configuration:
  # I0617 23:17:14.193512    8871 x:0]              RootDir: /run/containerd/runsc/k8s.io
  # I0617 23:17:14.193597    8871 x:0]              Platform: ptrace
  # I0617 23:17:14.193674    8871 x:0]              FileAccess: proxy, overlay: false
  # I0617 23:17:14.193752    8871 x:0]              Network: sandbox, logging: false
  # I0617 23:17:14.193827    8871 x:0]              Strace: false, max size: 1024, syscalls: []
  # I0617 23:17:14.193900    8871 x:0] ***************************
  # ID                                                                 PID         STATUS      BUNDLE   CREATED                          OWNER
  # 04e1dc8c98fe962505cdcedc88270ac904aa5abb2ecfb52f9dd94cff80bd4de8   8497        running     /run/containerd/io.containerd.runtime.v1.linux/k8s.io/04e1dc8c98fe962505cdcedc88270ac904aa5abb2ecfb52f9dd94cff80bd4de8   2018-06-17T23:14:29.136242526Z
  # 8fe4df95d40652e38aa8b6a1c4bea32b60fbace9015213d8a59bf8cda8c5a6c2   8552        running     /run/containerd/io.containerd.runtime.v1.linux/k8s.io/8fe4df95d40652e38aa8b6a1c4bea32b60fbace9015213d8a59bf8cda8c5a6c2   2018-06-17T23:14:31.07918563Z
  # I0617 23:17:14.196015    8871 x:0] Exiting with status: 0

  # Get the ID of the untrusted pod.
  local POD_ID=$(sudo crictl -r unix:///var/run/containerd/containerd.sock \
    pods --name untrusted -q)

  # Get the ID of the webserver container running in the untrusted pod.
  local CONTAINER_ID=$(sudo crictl -r unix:///var/run/containerd/containerd.sock \
    ps -p ${POD_ID} -q)
  
  # Use the gVisor runsc command to display the processes running inside the webserver container.
  sudo runsc --root /run/containerd/runsc/k8s.io ps ${CONTAINER_ID}
  # Expected result.
  # I0617 23:21:13.782363    9117 x:0] ***************************
  # I0617 23:21:13.782522    9117 x:0] Args: [runsc --root /run/containerd/runsc/k8s.io ps 8fe4df95d40652e38aa8b6a1c4bea32b60fbace9015213d8a59bf8cda8c5a6c2]
  # I0617 23:21:13.782580    9117 x:0] Git Revision: 08879266fef3a67fac1a77f1ea133c3ac75759dd
  # I0617 23:21:13.782625    9117 x:0] PID: 9117
  # I0617 23:21:13.782671    9117 x:0] UID: 0, GID: 0
  # I0617 23:21:13.782725    9117 x:0] Configuration:
  # I0617 23:21:13.782759    9117 x:0]              RootDir: /run/containerd/runsc/k8s.io
  # I0617 23:21:13.782834    9117 x:0]              Platform: ptrace
  # I0617 23:21:13.782910    9117 x:0]              FileAccess: proxy, overlay: false
  # I0617 23:21:13.782985    9117 x:0]              Network: sandbox, logging: false
  # I0617 23:21:13.783060    9117 x:0]              Strace: false, max size: 1024, syscalls: []
  # I0617 23:21:13.783139    9117 x:0] ***************************
  # UID       PID       PPID      C         STIME     TIME      CMD
  # 0         1         0         0         23:14     10ms      app
  # I0617 23:21:13.784504    9117 x:0] Exiting with status: 0
}


function delete-smoke-test() {
  gcloud compute -q firewall-rules delete kubernetes-the-hard-way-allow-nginx-service
}

# Main ************************************************************************
#

# If provided, execute the specified function.
if [ ! -z "$1" ]; then
  $1
fi