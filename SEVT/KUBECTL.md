# A gentle tour of ```KUBECTL``` 


## 0. Goals
The goals of this lab are for you to configure ```kubectl``` to communicate with the big kubernetes cluster.  Then you will run a few basic kubectl commands to show key concepts. This lab seeks to be a gentle introduction to kubernetes.  

## 1. Setup Kubectl

### 1.1 Grab the certificate file
```
cp /tmp/ca.pem . 
```

### 1.2. Set local environment variables
Set the environment variables you'll need for this lab: 

```
export CLUSTER_IP=<clusterip>
export TOKEN=<token>
```
The values for these variables are in the spark room.

### 1.3. Set the ```NAMESPACE```

In this lab, every user will use their own namespace so as not to clobber other users.  Set the namespace by running the command: 

```
export NAMESPACE=<yournamespace>
```

Where ```<yournamespace>``` is a combination of your initials plus your lab number: ```<username><your initials>```

As an example, If my name were Captain Cloud and I was user ```user68```, then I would run the command: ```export NAMESPACE=user68cc```

Be sure your namespace is ALL lowercase characters. **DO NOT USE UPPERCASE.** It is OK to run the same command with a correct unique namespace now.


### 1.4. Configure ```kubectl```

After running each of the below commands you may wish to run ```cat ~/.kube/config```.  (If you run it now it will fail because no file has been created yet!) You'll see that these next set of commands will modify that file.  ```kubectl``` looks in that file for how to target the appropriate kubernetes cluster. 

#### Define the cluster
```
kubectl config set-cluster sevt --server="https://$CLUSTER_IP/" --certificate-authority=ca.pem --embed-certs=true
```

#### Enter user credentials
```
kubectl config set-credentials admin --token $TOKEN
```

#### Set the default-context to our cluster

```
kubectl config set-context default-context --cluster=sevt --user=admin
```

#### Use the default-context
```
kubectl config use-context default-context
```

#### Set the default namespace to be our namespace

```
kubectl config set-context default-context --namespace=$NAMESPACE
```

#### Checkpoint 

At this point all the commands you have run modified the ```~/.kube/config``` file.  If you have done everything correctly, you should be able to see all the nodes.  Try running: 

```
kubectl get nodes
```

If you see all the nodes of the cluster give yourself a pat on the back!  You are doing great things!  If it didn't work, please let the proctors know. 

#### Create the namespace on the kubernetes cluster

__IMPORTANT:__ Because there multiple people running on the same cluster, every user needs to run in their own namespace.  You created the default namespace above in your ```~/.kube/config``` file, but now you need to actually create that namespace on the kubernetes cluster:

```
kubectl create namespace $NAMESPACE
```

## 2. Test Drive ```kubectl```

You are now ready to interact with the cluster.  Try a few commands.

### 2.1. Get nodes in the cluster: 

We can see how many nodes are defined in our cluster. 

```
kubectl get nodes
```

### 2.2.  Get general cluster information

Get the cluster info:

```
kubectl cluster-info
```
Get the component status:

```
kubectl get componentstatuses
```

### 2.3.  Get help from kubernetes! 
Have a question about what one of the resources does?  You can have kubectl explain it to you: 

```
kubectl explain pods
```
As usual you can also run the -h flag after any sub command to find more about the topic. 

```
kubectl rolling-update -h 
```

### 2.4.  See what containers/pods are running

Now let's see what's running in the cluster:

```
kubectl get pods 
```

Here you may not see anything running because by default you're only looking at pods in your own namespace.  

Let's see what's running outside your namespace: 

```
kubectl get pods --all-namespaces
```

You can also see where the pods are running.  This helps with troubleshooting.  

```
kubectl get pods -o wide --all-namespaces
```

### 2.5. follow the changes

If you are familiar with the linux ```tail -f``` command or ```watch``` command, kubernetes has a great way of monitoring changes by using a ```-w``` option at the end of the ```get pods``` command.  This is done by running the command: 

```
kubectl get pods -o wide --all-namespaces -w
```
You can watch for any changes as other lab participants create pods.  To exit this command type ```control+c``` or while holding down the control key on your computer tap the 'c' key. 

## 3. Run containers with ```kubectl```

In this section we'll run a few commands to manipulate pods and containers. 

### 3.1.  Start up busybox

Start up a simple [busybox](https://busybox.net/about.html) deployment by running:

```
kubectl run bb --image=busybox --command -- sleep 3600
```

This command creates 

* A deployment named ```bb```
* A pod that runs with the deployment. 

### 3.2. Verify busybox

Check for your self that these are running: 

```
kubectl get deployments
kubectl get pods
```
You'll see there is a deployment named ```bb``` and a pod running called ```bb-<some-random-stuff>```.  

The deployment states the intent of the pods.  By default we only ran one instance of the busybox container.  

### 3.3. Try to kill a pod

Let's see what happens when we try to kill the busybox pod: 

```
kubectl get pods
```
Make note of your busybox pod.  (It will be something like ```bb-209343k43-core79```.)

Kill the running pod:

```
kubectl delete pod <name of your pod>
```
e.g: ```kubectl delete pod bb-209343k43-core79```.

Now look at the pods again:

```
kubectl get pods
```

Did the pod go away?  What happened?  Why?  

### 3.4. Examine busybox deployment

Everytime you killed a pod in the previous step Kubernetes brought up a new one in its place.  This is because the ````kubectl run``` command you ran above created a [deployment](http://kubernetes.io/docs/user-guide/deployments/). 

Take a look at the deployment you created: 

```
kubectl describe deployment bb
```

This makes sure that there is always at one busybox pod running. Deployments used to be called replication controllers.  They control how the pods run.  

## 4. Further Pod Exploration

These commands are used during debuggging and are pretty handy for figuring out what is going on with applications in your system. 

### 4.1. Show logs

We can show the logs of a container.  Run the command:

```
kubectl logs <pod name>
```
where ```<pod name>``` is the name of the running busybox container. 

Now since busybox doesn't have any logs, you won't see anything in the output, but if you were running something like nginx or another service you would see all the great logs from this. 

### 4.2. Exploring a running container

We can also attach to a running pod and see what's happening inside of it.  Attach to your busy box container by running: 

```
kubectl exec -it bb-2097322085-mv9ab -- /bin/sh
```
This will drop you into the busybox shell on the container.  Here we can run commands to explore how the container was set up: 

```
cat /etc/resolv.conf
```
You'll see that there is ```cluster.local``` and several other kubernetes DNS settings in there, including your namespace.  You'll also notice that the nameserver is set to ```10.32.0.10```.  This is the service that was set up prior and is running in a container.  

To show that DNS is functioning, try resolving the name of the dashboard: 

```
nslookup kubernetes-dashboard.kube-system.svc.cluster.local
```
Here you can see that DNS tells us the cluster IP of the server.  We can also do a ```wget``` to grab the dashboard web page: 

```
wget kubernetes-dashboard.kube-system.svc.cluster.local:9999
```
We use port 9999 because that was what we specified in the kubernetes-dashboard deployment that was run earlier. 

You won't be able to ping this service because the kube-proxy service that runs on each host only forwards the specified port with tcp.  ICMP queries don't go through.  

Exit out of the busybox container

```
exit
```
### 4.3.  Delete the busybox Deployment

You should now be back on your workstation. 

Delete the busybox deployment.  This will also delete the pods. 

```
kubectl delete deployment bb
```
Make sure there are no pods left by running:

```
kubectl get pods
```
The output should be empty.  Good job!


You are done!  Go back to the [Main Page](README.md)
