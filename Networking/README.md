# Kubernetes Networking

### Kube-apiserver
[Kube API server Documentation](http://kubernetes.io/docs/admin/kube-apiserver/)

```
--advertise-address=${hostip}
```
This we just set to the internal IP address of the VM.  In the case of Opentack it's the non floating IP address. 
 
```
--bind-address=0.0.0.0
```
The default is ```0.0.0.0``` so that all interfaces can reach the bind-address. 

```
--insecure-bind-address=0.0.0.0
```

The default is to allow insecure binding on localhost (127.0.0.1) by setting to 0.0.0.0 we are allowing insecure access from any interface.  By doing 127.0.0.1 (the default) then it is only exposed to people logged onto the machine where the kube-apiserver is running.

```
--service-cluster-ip-range=${service_cluster_ip_range}
```
IP range from which to asign service cluster IPs.  This shouldn't overlap with IP ranges assigned to nodes for pods.  

We use ```10.32.0.0/24``` for our services.  

```
--service-node-port-range=${service_port_range}
```
This is the port range reserved for services with NodePort visibility.  We use ```3000-32767``` as this is shown in the examples and works well. 

### kube-controller-manager

```
--allocate-node-cidrs=true
```
We want CIDRs for pods be allocated and set on the cloud provider.  

```
--cluster-cidr=${cluster_cidr}
```
We use ```10.200.0.0/16``` as the range for pods in the cluster. 

```
--master=http://${hostip}:8080
```
This can be set to the API server.  As this node is a master node it can just point to itself.  The kube API insecure port is 8080.  Here we are pointing it to itself. 

```
--service-cluster-ip-range=${service_cluster_ip_range}
```
We use ```10.32.0.0/24``` as these are the IP addresses allocated to kubernetes services. 



## Services on Worker nodes

### kube-proxy
[Kube Proxy Documentation](http://kubernetes.io/docs/admin/kube-proxy/)

Kube-proxy gets installed on all the worker nodes. 

```
--master=https://<master IP address>
```
This is the addres of the Kubernetes API server. This should be set to the loadbalancer IP address if you are using a load balancer. 

If you go directly to a server then you'll need to put the port ```6443``` at the end.  Otherwise that can be configured with the load balancer to send secure requests to that port. 

```
--proxy-mode=iptables
```

### Kubelet
The kubelet runs on each node.  There are several values we use to configure this for the networking we want. 

For using networking based on routing, we use the following flags: 

```
--configure-cbr0=true
--reconcile-cidr=true
```

This means an IP address will be allocated for each pod from the ```podCIDR``` range assigned to each worker.  Since we specified a ```--cluster-cidr=${cluster_ip}``` network (10.200.0.0/16) then each node will receive a ```/24``` subnet. 

[Kelsey Hightower]( https://twitter.com/kelseyhightower) has given us a nice command to be able to figure out which network each node has: 

```
kubectl get nodes \
  --output=jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address} {.spec.podCIDR} {"\n"}{end}'
```
Gives an output like: 

```
10.240.0.20 10.200.0.0/24 
10.240.0.21 10.200.1.0/24 
10.240.0.22 10.200.2.0/24 
```
e.g: node internal IP address and associated Pod subnet.  In the above examples all pods created on VM ```10.240.0.20``` will be assigned an address in the ```10.200.0.0/24``` range, such as ```10.200.0.56```. 


As we would like OpenStack to handle the networking for us we can then run: 

```
openstack subnet set --host-route destination=10.200.0.0/24,gateway=10.106.1.2 pipeline_sub
openstack subnet set --host-route destination=10.200.2.0/24,gateway=10.106.1.3 pipeline_sub
openstack subnet set --host-route destination=10.200.1.0/24,gateway=10.106.1.5 pipeline_sub
openstack subnet set --host-route destination=10.200.3.0/24,gateway=10.106.1.6 pipeline_sub
openstack subnet set --host-route destination=10.200.4.0/24,gateway=10.106.1.4 pipeline_sub
openstack subnet set --host-route destination=10.200.5.0/24,gateway=10.106.1.7 pipeline_sub
```
To set the routing from OpenStack as opposed to installing an overlay network like flannel or weave. 

```
--cluster-dns=${cluster_dns}
```
when we run ```kubectl cluster-info``` we see the KubeDNS service running. 

```
--cluster-domain=cluster.local
```


