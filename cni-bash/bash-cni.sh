#!/bin/bash -e

if [[ ${DEBUG} -gt 0 ]]; then set -x; fi

exec 3>&1 # make stdout available as fd 3 for the result
exec &>> /var/log/bash-cni-plugin.log

IP_STORE=/tmp/reserved_ips # all reserved ips will be stored there

echo "CNI command: $CNI_COMMAND" 

stdin=`cat /dev/stdin`
echo "stdin: $stdin"

# Iterates over all_ips and reserved_ips, finds the first 
# non-reserved IP, and updates the /tmp/reserved_ips file.
function allocate_ip(){
	for ip in "${all_ips[@]}"
	do
		reserved=false
		for reserved_ip in "${reserved_ips[@]}"
		do
			if [ "$ip" = "$reserved_ip" ]; then
				reserved=true
				break
			fi
		done
		if [ "$reserved" = false ] ; then
			echo "$ip" >> $IP_STORE
			echo "$ip"
			return
		fi
	done
}

# ADD -------------------------------------------------------------------------
# 
function add() {
	# Extract network, subnet, subnet_mask_size from the input stream: 
	# CNIconfig: /etc/cni/net.d/10-bash-cni-plugin.conf
	# 
	network=$(echo "$stdin" | jq -r ".network")
	subnet=$(echo "$stdin" | jq -r ".subnet")
	subnet_mask_size=$(echo $subnet | awk -F  "/" '{print $2}')

	# Allocate IPS
	#
	# Find all IPs on subnets
	all_ips=$(nmap -sL $subnet | grep "Nmap scan report" | awk '{print $NF}')
	# Create array of all IPs.
	all_ips=(${all_ips[@]})
	# Always skip first IP pf a subnet (e.g. 10.244.0.0)... 
	skip_ip=${all_ips[0]}
	# ... and assume that the next IP (10.244.0.1) will be a gateway for all 
	# containers.
	gw_ip=${all_ips[1]}
	# These are reserved can cannot be allocated (e.e. reserving 10.244.0.0 
	# and 10.244.0.1) 
	reserved_ips=$(cat $IP_STORE 2> /dev/null || printf "$skip_ip\n$gw_ip\n") 
	reserved_ips=(${reserved_ips[@]})
	printf '%s\n' "${reserved_ips[@]}" > $IP_STORE
	# An IP can then be allocated from the remainer of unallocated IPS.
	container_ip=$(allocate_ip)

	# Create namespace and VETH pair
	# 
	# The CNI spec stipulates the caller (in our case, kubelet) must create a 
	# network namespace and pass it in the CNI_NETNS environment variable.

	# Create network namespace
	mkdir -p /var/run/netns/
	ln -sfT $CNI_NETNS /var/run/netns/$CNI_CONTAINERID

	# Create VETH pair
	#
	rand=$(tr -dc 'A-F0-9' < /dev/urandom | head -c4)
	host_if_name="veth$rand"
	# Configur the interface 
	# 
	# The interfaces are created as an interconnected pair. Packages transmitted to one of 
	# the devices in the pair are immediately received on the other device. CNI_IFNAME 
	# is provided by the caller and specifies the name of the network interface that will 
	# be assigned to the container (usually, eth0). The name of the second network interface 
	# is generated dynamically.
	ip link add $CNI_IFNAME type veth peer name $host_if_name 
	# The second interface remains in the host namespace and should be added to the bridge.
	# This interface will be responsible for receiving network packets that appear in the 
	# bridge and are intended to be sent to the container.
	ip link set $host_if_name up 
	ip link set $host_if_name master cni0 

	# Configure container interface
	#
	# Move the interface to the new network namespace. After this step, nobody 
	# in the host namespace will be able to communicate directly with the 
	# container interface. All communication must be done only via the host pair.
	ip link set $CNI_IFNAME netns $CNI_CONTAINERID
	# Assign the previously allocated container IP to the interface. 
	# NB: 'exec' is used to 'shell in' to the other network namespace. 
	ip netns exec $CNI_CONTAINERID ip link set $CNI_IFNAME up
	ip netns exec $CNI_CONTAINERID ip addr add $container_ip/$subnet_mask_size dev $CNI_IFNAME
    # Create a default route that redirects all traffic to the default gateway,
	# which is the IP address of the cni0 bridge).
	ip netns exec $CNI_CONTAINERID ip route add default via $gw_ip dev $CNI_IFNAME 

	# Return the information to the caller
	# 
	mac=$(ip netns exec $CNI_CONTAINERID ip link show eth0 | awk '/ether/ {print $2}')
echo "{
  \"cniVersion\": \"0.3.1\",
  \"interfaces\": [                                            
      {
          \"name\": \"eth0\",
          \"mac\": \"$mac\",                            
          \"sandbox\": \"$CNI_NETNS\" 
      }
  ],
  \"ips\": [
      {
          \"version\": \"4\",
          \"address\": \"$container_ip/$subnet_mask_size\",
          \"gateway\": \"$gw_ip\",          
          \"interface\": 0 
      }
  ]
}" >&3
}

# DELETE ----------------------------------------------------------------------
# 
function delete() {
	ip=$(ip netns exec $CNI_CONTAINERID ip addr show eth0 | awk '/inet / {print $2}' | sed  s%/.*%% || echo "")
	if [ ! -z "$ip" ]
	then
		sed -i "/$ip/d" $IP_STORE
	fi
}

# GET -------------------------------------------------------------------------
# 
function get() {
	echo "GET not supported"
	exit 1
}

# VERISON ---------------------------------------------------------------------
# 
function version() {
	echo '{
	"cniVersion": "0.3.1", 
	"supportedVersions": [ "0.3.0", "0.3.1", "0.4.0" ] 
	}' >&3
}


case $CNI_COMMAND in
ADD)
	add
;;

DEL)
	delete
;;

GET)
	get
;;

VERSION)
	version
;;

*)
  echo "Unknown cni commandn: $CNI_COMMAND" 
  exit 1
;;

esac