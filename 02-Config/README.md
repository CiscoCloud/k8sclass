# 2. Configure Kubernetes

The previous lab just did all the set up for you to install kubernetes, but there is still some steps we need to complete!

## Verify Installation

Our kubernetes cluster is front-ended by an nginx reverse proxy load balances that uses the 3 controllers.  

Remember in the last lab that you named your load balancer?  What was the name?  Whatever it was, the terraform script added at ```01``` to the end of it.  So if you named your load-balancer ```cc-lb``` the name you need is ```cc-lb01```

Once you know this, run the following commands substituting <lb> in with your load balancer name (like ```fonzi-lb01```)

```bash
export LB=<cc-nginx01>
export CLUSTER_IP=$(openstack server list | grep -i $LB \
	 | awk -F"|" '{print $5}' | awk -F, '{print $2}' | xargs)
echo $CLUSTER_IP
```

Make sure that last command returns an IP address.  If you have trouble, you can run the ```openstack server list``` command and look for the floating IP address assigned to your load balancer.

### Log into load balancer

```bash
ssh -i ~/.ssh/<key>.pem ubuntu@$CLUSTER_IP
```
When you log in you should see the SSH key sitting in this directory.  Verify that your ```/etc/hosts``` file includes the names of your nodes.  

Log into one of your controller nodes and check that the nodes are up: 

```bash
ssh -i ~/<key>.pem <controller0X>
```
e.g:

```
ssh -i ~/captaincloud.pem cc-kube-controller02
```

Once logged in see if nodes are up: 

```
ubuntu@cc-kube-controller02:~$ kubectl get nodes
NAME              STATUS    AGE
cc-kube-worker01   Ready     4h
cc-kube-worker02   Ready     4h
cc-kube-worker03   Ready     4h
```

If the nodes are up and ready you can move to the next step!

## kubectl

```kubectl``` is the command we use to communicate with our kubernetes cluster.  It was installed on the controller nodes, but now you need to make it work from your workstation or your lab machine. 

To set up ```kubectl``` so it can communicate with the cluster we will follow the instructions from [Kelsey Hightower's Kuberentes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/06-kubectl.md)

__Log off of from the controller nodes to do the following.__

### Give Cluster a name
Name your cluster something fun.  You'll have to look in your ```metacloud.tf``` file and try to match this.  (It doesn't have to, but its a good idea).  Hint:  ```grep cluster_name metacloud.tf | grep variable``` to get the name. 


```
export CLUSTER=<cluster_name>
```
Now let's configure ```kubectl```

```
cd certs/
kubectl config set-cluster $CLUSTER --server='https://<CLUSTER_IP>' --certificate-authority=ca.pem --embed-certs=true
```

Remember the token we set in the Terraform file?  You can fish that (hint: ```grep token metacloud.tf | grep variable```) out and run the following command so we can speak with that cluster:

```
kubectl config set-credentials admin --token <token>
```

```
kubectl config set-context default-context \
  --cluster=$CLUSTER \
  --user=admin
```

```
kubectl config use-context default-context
```

You should be able to connect from your local machine to the kubernetes cluster through the nginx load balancer:

```
kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-0               Healthy   {"health": "true"}   
etcd-2               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"}
```
```
kubectl get nodes
NAME        STATUS    AGE
kworker01   Ready     1h
kworker02   Ready     1h
kworker03   Ready     1h
```

[More source info](http://kubernetes.io/docs/user-guide/kubectl-cheatsheet/)

Now you are set up to talk to the kubernetes cluster from your workstation!

## Configure overlay networking

In most of the kubernetes guides you'll find recommendations to use weave, flannel, calico, or some other networking overlay.  With OpenStack, we already have a network overlay called neutron, so we'll use it!

This method is also similar to using bare metal kubernetes where there is a simple network switch connecting all nodes. 

(Note: For other information on this section see [this excellent blog post](http://blogs.cisco.com/cloud/deploy-a-kubernetes-cluster-on-openstack-using-ansible))

We'll have to first define our static routes.  

Open up the ```generate-neutron-routes.py``` script found in the same directory as the ```metacloud.tf``` file.  There are two variables that need to be changed near the beginning of the file.  These are: 

```
prefix = "fonzi-worker"
net_prefix = "10.214"
```
Change the prefix to match the worker_name in your ```metacloud.tf``` file for the worker nodes.  

Change the net_prefix to match the ```cluster_nets_prefix``` and ```cluster_cidr``` prefix.  

```
./generate-neutron-routes.py
```
This gives us output like: 

```
neutron port-update 3325e20d-29b0-4da7-ac2f-5ad54ab390f3 --allowed-address-pairs type=dict list=true ip_address=10.214.0.0/24
neutron port-update 9958fc43-075d-4577-9374-467c21c19371 --allowed-address-pairs type=dict list=true ip_address=10.214.1.0/24
neutron port-update 550eabc3-df51-4586-9680-b4b3f7279bea --allowed-address-pairs type=dict list=true ip_address=10.214.2.0/24
```

These are the openstack commands that need to be run to enable the routes for your kubernetes cluster.  Since your openstack user doesn't have the ability to run these commands then you'll have to get these commands to the instructor so they can run these commands for you. 

Once they run these commands they will let you know and you can move on!



## Kubernetes DNS

From our workstation we can now run the following commands to get kubernetes DNS running on our cluster: 

```
kubectl create -f https://raw.githubusercontent.com/CiscoCloud/k8sclass/master/02-Config/services/kubedns.yaml
```
This creates a service called kube-dns.  What it will do is it will look for any pods with app name = kube-dns.  Then it will open up IP address ```10.32.0.10``` to them. You can read more about Kuberentes services [here](http://kubernetes.io/docs/user-guide/services/)

Now you can run the command: 

```
kubectl --namespace=kube-system get svc
```

Next we will create the DNS deployment.  This is where we will actually build several containers with kuberentes.  

Run the command: 

```
kubectl create -f https://raw.githubusercontent.com/CiscoCloud/k8sclass/master/02-Config/deployments/kubedns.yaml
```

Kuberentes reads the file and deploys containers based on what it says to do.  You can [look at the file here](https://github.com/CiscoCloud/k8sclass/blob/master/02-Config/deployments/kubedns.yaml).  Notice that the ```kind``` is ```Deployment```.  There are 3 container images specified that will be deployed:  ```kubedns```, ```dnsmasq```, and ```healthz```.  These containers will all be deployed in a single pod.  Line 25 also shows that 2 of these pods will be created.  

Check that services are up

```
kubectl --namespace=kube-system get deployments
kubectl --namespace=kube-system get svc
kubectl --namespace=kube-system get pods -o wide
```
If all goes well that last command should give you output similar to: 

```
NAME                            READY     STATUS    RESTARTS   AGE       IP           NODE
kube-dns-v20-1485703853-7y7o6   3/3       Running   0          50s       10.214.0.2   fonzi-vworker01
kube-dns-v20-1485703853-j6dh7   3/3       Running   0          50s       10.214.2.2   fonzi-vworker03

```

Hurray!  Now kubedns is up!

## Kubernetes Dashboard


First we will install the dashboard as a basic deployment (e.g: Pods): 

```
kubectl create -f https://raw.githubusercontent.com/CiscoCloud/k8sclass/master/02-Config/deployments/kubernetes-dashboard.yaml
```
Make sure its up:

```
$ kubectl get pods -n kube-system
NAME                                    READY     STATUS    RESTARTS   AGE
kube-dns-v20-1485703853-oc6hj           3/3       Running   0          3m
kube-dns-v20-1485703853-pp1ko           3/3       Running   0          3m
kubernetes-dashboard-3203700628-5zhl8   1/1       Running   0          12s
```

Now, how can we access this dashboard externally?  By default, these services are not exposed outside the cluster.  What we can do is create a service from this deployment.  

Download a template file running: 

```
wget https://raw.githubusercontent.com/CiscoCloud/k8sclass/master/02-Config/services/dashboard.yaml
```

Edit this file.  You will see that there are three places where you can add your worker node IP addresses:

```yaml
...
 externalIPs:
  - <worker1 IP address>
  - <worker2 IP address>
  - <worker3 IP address>
...
```
Substitute the values of your worker IP addresses.  You can get the IP addresses in the ```hostfile``` in the same directory where the ```metacloud.tf``` file is or use the ```openstack server list``` command. 

When completed it should look something like this: 

```yaml
...
 externalIPs:
  - 192.168.7.107
  - 192.168.7.105
  - 192.168.7.110
...
```

Now you can deploy this service: 

```
kubectl create -f dashboard.yaml
```
(make sure you run that command in the same directory where the ```dashboard.yaml``` file is that you just edited!)

If all went well, you should be able to see this service running: 

```bash
kubectl get svc -n kube-system
NAME                   CLUSTER-IP   EXTERNAL-IP                                 PORT(S)         AGE
kube-dns               10.32.0.10   <none>                                      53/UDP,53/TCP   6h
kubernetes-dashboard   10.32.0.11   192.168.7.107,192.168.7.105,192.168.7.110   9999/TCP        21m
```
Notice that the port that this service exposes is 9999.  If you look in the ```templates/nginx.conf.tpl``` file you'll see that we mapped port ```80``` externally to point to this ```9999``` internal port.  You should now be able to open a web browser and pull up the dashboard: 

```
http://<load-balancer-floating-ip-address>
```
You'll then be prompted for a user name and password.  We specified this in the ```metacloud.tf``` file.  (you can see it around line 239 with the ```htpasswd``` command)

```
username: kubeadm
```
```
password: k8sclass
```

If all goes well you should see the dashboard: 

![kubernetes file](images/kubedash.png)


## Optional Stuff (feel free to ignore)

(Ignore unless you want to see other ways to communicate with the API server)

### Using Curl to communicate with API server

Kubernetes gives us the ```kubectl``` command but it is just a client for accessing the Kubernetes API server.  We could access it directly with ```curl```. 

Go into the ```certs/``` directory again and run something like: 

```
curl --cacert kubernetes.pem -H "Authorization: Bearer <token>" https://<lb-public-ip>/api/v1/pods
```

Where ```<token>``` is what you defined in the ```metacloud.tf``` file and used in previous steps. 

This mimics to some extent what kubectl is doing.  We use the token and the certificate to authenticate with the API server.  This isn't the dashboard, this is simply the API. 

#### Using Kubectl proxy to access the API server

If we didn't have nginx front loading and providing us a way into the cluster we could proxy into the lab.  Running the command: 

```
kubectl proxy -n <port>
```
Where port = 8000 + <your lab group>, e.g.: 8001, 8002, ...

This will open port 800X that lets you access the dashboard via the web interface at ```https://localhost:800X/api/v1/pods```.  



