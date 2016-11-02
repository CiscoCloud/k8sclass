# Troubleshooting Kubernetes Networking

There is a [great guide](http://kubernetes.io/docs/user-guide/debugging-services/#my-service-is-missing-endpoints) we use to figure out what is happening with the network.  

## Step 1 Launch a test node

```
kubectl run -i --tty busybox --image=busybox --generator="run-pod/v1"
```
If you've already got this running and you're coming back to it, you can restart it

```
kubectl attach busybox -c busybox -i -t
```
Inside of ```/etc/resolv.conf``` should be your local domain as well as the proper nameserver:

```
search default.svc.cluster.local svc.cluster.local cluster.local novalocal
nameserver 10.32.0.10
options ndots:5
```
So the container will try to resolve other containers and services via the 10.32.0.10 nameserver. 

This nameserver was setup when we deployed it.  We deployed it as: 

```
kubectl create -f https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/services/kubedns.yaml
```
The kubedns.yaml file looked as follows: 

```
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "KubeDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: 10.32.0.10 
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
```
This when installed was verified with: 

```
kubectl --namespace=kube-system get svc
kubectl --namespace=kube-system get pods
```
On the last command I once saw it say: 

```
NAME                                    READY     STATUS             RESTARTS   AGE
kube-dns-v20-1485703853-9ynjz           2/3       CrashLoopBackOff   3227       4d
kube-dns-v20-1485703853-rrkxw           1/3       CrashLoopBackOff   3227       4d
```
After realizing my kube-proxy was set incorrectly, I restarted the kube-dns service as follows: 

```
kubectl --namespace=kube-system delete svc kube-dns
```
I then fixed my ```kube-proxy``` file on the nodes.  Then I restarted the service running the command: 

```
kubectl create -f https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/services/kubedns.yaml
```
Still upon inspection the nodes showed CrashLoopBackOff.  Time to inspect the logs to see what was going on: 

```
kubectl --namespace=kube-system logs kube-dns-v20-1485703853-9ynjz kubedns
```
There are also 2 other containers in the pod: ```dnsmasq``` and ```healthz```.  Here we see that the reason its crashing is because ```healthz``` is giving us errors:

```
Result of last exec: nslookup: can't resolve 'kubernetes.default.svc.cluster.local'
```
So something is wrong with kubedns.  THe error states:
```
Ignoring error while waiting for service default/kubernetes: Get https://10.32.0.1:443/api/v1/namespaces/default/services/kubernetes: dial tcp 10.32.0.1:443: i/o timeout. Sleeping 1s before retrying.
```
So just how is this container accessing 10.32.0.1:443 which is supposed to be the service IP address. 

We use iptables to create the virtual IP address.  So we go to ip tables on the node that the service is running on.  (We found this with ```kubectl get pods -o wide``` 

```
iptables -L 
```
Here it says: 

```
target     prot opt source               destination         
REJECT     udp  --  anywhere             10.32.0.10           /* kube-system/kube-dns:dns has no endpoints */ udp dpt:domain reject-with icmp-port-unreachable
```
So why doesn't it have any endpoints? 

Also we can run: 
```
iptables-save
```
We can also check on the service by SSHing to one of the controller nodes and running:

```
curl http://localhost:8080/api/v1/proxy/namespaces/kube-system/services/kube-dns
```
Here we get similar information: 

```
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "no endpoints available for service \"kube-dns\"",
  "reason": "ServiceUnavailable",
  "code": 503
}
```
After some [searching](http://stackoverflow.com/questions/38411595/kubernetes-dashboard-keeps-pending-with-message-no-endpoints-available-for-serv) I found one possible reason it wasn't running was because there was no scheduler running.  How do we check that the kube-scheduler is actually running? 

Try deleting the service and the deployment again

```
kubectl --namespace=kube-system delete svc kube-dns
kubectl --namespace=kube-system delete deployment kube-dns-v20
```
Make sure they're gone

```
kubectl --namespace=kube-system get deployments
kubectl --namespace=kube-system get svc
```
Now restart them: 

```
kubectl create -f https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/services/kubedns.yaml

kubectl create -f https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/deployments/kubedns.yaml
```
Verify again

```
kubectl --namespace=kube-system get deployments
kubectl --namespace=kube-system get svc
```

Hmm.. .this is tough.  Looking back it says in the logs: 

```
kubectl --namespace=kube-system logs kube-dns-v20-1485703853-8rht5 kubedns
I1026 20:36:45.176359       1 server.go:94] Using https://10.32.0.1:443 for kubernetes master, kubernetes API: <nil>
```
So why is it using ```10.32.0.1:433``` as the kubernetes master? 

Ah!  Because it is what is shown: 

```
kubectl get svc
NAME         CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   10.32.0.1    <none>        443/TCP   4d
my-nginx     10.32.0.37   <nodes>       80/TCP    1d
```

This seems to be ok? 

```
kubectl describe svc kubernetes
Name:			kubernetes
Namespace:		default
Labels:			component=apiserver
			provider=kubernetes
Selector:		<none>
Type:			ClusterIP
IP:			10.32.0.1
Port:			https	443/TCP
Endpoints:		10.106.1.2:6443,10.106.1.3:6443,10.106.1.5:6443
Session Affinity:	ClientIP
```
But where is the route to this 10.32.0.1 so that services can be reached? 

At this point if we go to one of the workers where the container is running we can try to reach the service ourselves: 

```
curl 10.32.0.1
```
We get a response so we know we can reach it from the node.  We've now isolated the problem to the fact that the container can not get to the virtual 10.32.0.1 network.

As one example, (launching busybox) the node is assigned the IP address ```10.200.0.4```.  This node uses ```10.200.0.1``` as the default gateway.  This is the ```cbr0`` interface on the node.  

First test, can it even reach the ```10.200.0.1``` interface? 

```
ping 10.200.0.1
```

Nope.  So we can't connect from the container to the cbr interface.  Why is that? 

```
docker inspect .. 
```
The container shows that the container has no network connecitons at all.  

```
"NetworkSettings": {
            "Bridge": "",
            "SandboxID": "",
            "HairpinMode": false,
            "LinkLocalIPv6PrefixLen": 0,
            "Ports": null,
            "SandboxKey": "",
            "SecondaryIPAddresses": null,
            "SecondaryIPv6Addresses": null,
            "EndpointID": "",
            "Gateway": "",            
```
so we still have issues. 

### Test machine to see what happens when starting from scratch. 

Spin up a new docker instance and understand networking

```
brctl addbr cbr0
ip addr add 10.200.14.1/24 dev cbr0
ip link set dev cbr0 up
ip addr show cbr0
```
Now test it
```
docker run -it --name bb busybox /bin/sh
```
Here I can actually ping the gateway ```10.200.14.1``` so there must be some issues with my other running systems. 

Now see if we can connect to a running container: 

```
docker run -d -P --name n1 nginx
```

Ok that seem ok, though we can't do a ```wget``` and connect to the port unless we do it with the 0.0.0.0 option, which might work.  Let's go back and fix our other node to get it like the docker node. 

###  Back to controller01

```
systemctl stop kubelet
systemctl stop kube-proxy
systemctl stop docker
```
Now get rid of the docker part

```
apt-get install -y bridge-utils
systemctl stop kubelet kube-proxy docker
ip link set dev docker0 down
brctl delbr docker0
brctl addbr cbr0 
ip address add 10.201.0.1/24 dev cbr0
ip link set dev cbr0 up
iptables -t nat -F POSTROUTING # not sure what this did...
```
