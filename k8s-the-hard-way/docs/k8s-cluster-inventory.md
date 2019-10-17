# Kubernetes Cluster Inventory

A list of required resources and functions for creating a Kubernetes cluster.

---

## Resources

* __VNet__: Create a VNET.
* __VSNet__: Create a subnet with the required number of available nodes by CIDR.
    * require: VNEtId
    * require: CIDR range.
* 



---

## Functions

* __create-infra__ - Create networks, sub-networks, and compute instance.
* __create-pki__ - TODO.
* __create-kubeconfigs__ - TODO.
* __create-encryption__ - TODO.
* __create-etcd__ - TODO.
* __create-control-plane__ - TODO.
* __create-work-plane__ - TODO.
* __configure-kubectl__ - TODO.
* __verify__ - TODO.
* __create-pod-network-routes__ - TODO.
* __create-dns__ - TODO.


---

## Resources List


#### Source Scripts
* provision.sh 
* 03-provision-infra.sh
* 04-provision-pki.sh
* 05-provision-kubeconfigs.sh
* 06-provision-encryption.sh
* 07-provision-etcd.sh
* 08-provision-control-plane.sh
* 09-provision-work-plane.sh
* 10-provision-remote-access-kubectl.sh
* 11-provision-pod-network-routes.sh
* 12-provision-dns.sh
* 13-smoke-test.sh


#### Generated Scripts
* install-etcd.sh
* create-api-server-kubelet-rbac-script.sh                         
* install-kube-api-server.sh
* install-kube-scheduler.sh                 
* install-kube-controller-manager.sh       
* install-kubelet.sh
* install-kube-proxy.sh
* install-cni-networking.sh                 
* install-cri-containerd.sh   
* install-nginx-script.sh
* install-worker-base.sh



#### pki resources
* encryption-config.yaml
* ca-config.json, 
* ca.csr, ca-csr.json, ca-key.pem, ca.pem
* admin.csr, admin-csr.json, admin-key.pem, admin.pem
* kubernetes.csr, kubernetes-csr.json, , kubernetes-key.pem, kubernetes.pem
* kube-scheduler.csr, kube-scheduler-csr.json, kube-scheduler-key.pem, kube-scheduler.pem
* kube-controller-manager.csr, kube-controller-manager-csr.json, kube-controller-manager-key.pem, kube-controller-manager.pem 
* kube-proxy.csr, kube-proxy-csr.json, kube-proxy-key.pem, kube-proxy.pem
* service-account.csr, service-account-csr.json, service-account-key.pem, service-account.pem
* worker-0.csr, worker-0-csr.json, worker-0-key.pem, worker-0.pem
* worker-1.csr, worker-1-csr.json, worker-1-key.pem, worker-1.pem
* worker-2.csr, worker-2-csr.json, worker-2-key.pem, worker-2.pem
                

#### Kubeconfigs
* admin.kubeconfig
* kube-scheduler.kubeconfig
* kube-controller-manager.kubeconfig
* kube-proxy.kubeconfig
* worker-0.kubeconfig
* worker-1.kubeconfig
* worker-2.kubeconfig





