# Bash CNI Plugins

Exploring Kubernetes CNI.

---

## Notes

### Kubernetes Networking Model

* All the containers can communicate with each other directly without NAT.
* All the nodes can communicate with all containers (and vice versa) without NAT.
* The IP that a container sees itself as is the same IP that others see it as.

This can be achieved by allocating __a subnet for each container host__ and then set up __routing between the hosts__ to forward container traffic appropriately.

A CNI plug-in is responsible for allocating network interfaces to the newly created containers. Kubernetes first creates a container without a network interface and then calls a CNI plug-in.

#### IPv4 Forwarding

Host IPForwarding is a requirement, because each VM should accept packets with the destination IP set to a container IP rather then an IP of a virtual machine. This can be set via ```sysctl -w net.ipv4.ip_forward=1```.

#### Kubernetes Cluster Component Pod 'Host' Networking

Kubeadm can be used to install the kubernetes components on each instance and configure the networking. It can set up and configure __etcd__ and the kube control/data plane components Specifically, Kubeadm can alo configure Kubernetes to use the 10.244.0.0/16 CIDR range for the pod overlay networking.

Kubernetes can run with all components (__api-server__, __scheduler__, __kube-controller-manager__, __kube-proxy__, etc. ) deployed as pods - apart from the __kublet__ which is run as a __systemd__ service. This is because kubelet defines the __cri__ implementation such as __docker__ for managing the pods container life-cycle.. The K8s system components are defined in ```/etc/kubernetes/manifests/``` and have ```hostNetwork: true``` defined in their specs as the cni container networking is configured on top of this base system. These pods do not require CNI based networking.

#### Kubernetes Node Pod Networking

The whole __cluster pod network range__ gets __subdivided and associated with each node in the cluster__ as __node pod network ranges__. For example in a 2 node cluster:
```
10.244.0.0./16  =>  Node1: 10.244.0.0/24 (node container IP range: 10.244.0.0 – 10.244.0.255) (255 IPs)
                    Node2: 10.244.1.0/24 (node container IP range: 10.244.1.0 – 10.244.1.255) (255 IPs)
```

The __PodCIDRRange__ for a node can be obtained as follows:
```
./cni.sh kubectl describe node <node-name> | grep PodCIDR
```

#### CNI Config File

TODO

#### Network Bridge

Each node needs a __network bridge__ to link the host with it's pods. A network bridge is a special device that aggregates network packets from multiple network interfaces. 

The __CNI Plugin__ is responsible for adding networking interfaces for each container to the bridge so that they can communicate.

A bridge can have its own __MAC and IP address__ , so each container sees the bridges as another device on the network.

An IP address must be reserved for each bridge on each node. For example, in a 2 node cluster:
```
10.244.0.0./16  =>  Node1 Subnet: 10.244.0.0/24, Node1 Bridge IP: 10.244.0.1/32
                    Node2 Subnet: 10.244.1.0/24, Node2 Bridge IP: 10.244.1.1/32 
```

The bridge must be created, enabled, and assigned an IP address. For Node1:

```
temple@kNode1:~$ sudo brctl addbr cni0
temple@kNode1:~$ sudo ip link set cni0 up
temple@kNode1:~$ sudo ip addr add 10.244.0.0/24 dev cni0
```

The last command implicitly creates a route, so that all traffic with the destination IP belonging to the pod CIDR range, local to the current node, will be redirected to the cni0 network interface. For Node1:
```
temple@kNode1:~$ ip route | grep cni0
10.244.0.0/24 dev cni0  proto kernel  scope link  src 10.244.0.1
```

### CNI Plugin

The caller of a CNI plug-in (kubelet) must initialize the CNI_COMMAND environment variable, which contains the desired command. 

CNI plug-ins support four commands: __ADD__, __DEL__, __GET__, and __VERSION__.

#### ADD

#### DEL

#### GET

#### VERSION










---

#### Kubernetes Docs

* [CNI Plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
* [CNI Plugin Specification](https://github.com/containernetworking/cni/blob/master/SPEC.md)
* [CNI Plugin List](https://kubernetes.io/docs/concepts/cluster-administration/networking/#how-to-implement-the-kubernetes-networking-model)

* [Kubeadm](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/)
* [Install Kubeadm](https://kubernetes.io/docs/setup/independent/install-kubeadm/)
* [Kubeadm, Hops, and, Kubespray](https://www.altoros.com/blog/a-multitude-of-kubernetes-deployment-tools-kubespray-kops-and-kubeadm/)

* [Kubelet](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)
* [kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/)
* [Kubectl overview](https://kubernetes.io/docs/reference/kubectl/overview/)

* [Network Bridge](https://en.wikipedia.org/wiki/Bridging_(networking))

---

#### References

* [Simple Bash CNI Plugin](https://www.altoros.com/blog/kubernetes-networking-writing-your-own-simple-cni-plug-in-with-bash/)
    * [github](https://github.com/s-matyukevich/bash-cni-plugin)
* [Bash CNI Gist](https://gist.github.com/Andrei-Pozolotin/6bc4f2caa18700cdd94d910e588a555c)
* [Chaining CNI Plugins](https://karampok.me/posts/chained-plugins-cni/)
