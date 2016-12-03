# ```KUBECTL``` configuration

In this lab you will configure ```kubectl``` to communicate with the big kubernetes cluster.  

## Copy the certificate
```
cp /tmp/ca.pem . 
```

## Set local environment variables
Set the environment variables you'll need for this lab: 

```
export CLUSTER_IP=<clusterip>
export TOKEN=<token>
```
The values for these variables are in the spark room.

### Set the ```NAMESPACE```

In this lab, every user will use their own namespace so as not to clobber other users.  Set the namespace by running the command: 

```
export NAMEAPCE=<yournamespace>
```

Where ```<yournamespace>``` is a combination of your initials plus your lab number: ```<username><your initials>```

As an example, If my name were Captain Cloud and I was user ```user68```, then I would run the command: ```export NAMESPACE=user68cc```

## Configure ```kubectl```


```
kubectl config set-cluster sevt --server="https://$CLUSTER_IP/" --certificate-authority=ca.pem --embed-certs=true
```

```
kubectl config set-credentials admin --token $TOKEN
```

```
kubectl config set-context default-context --cluster=sevt --user=admin
```

```
kubectl config use-context default-context
```

```
kubectl config set-context default-context --namespace=$NAMESPACE
```

```
kubectl create namespace $NAMESPACE
```


## Test ```kubectl```

You are now ready to interact with the cluster.  Try a few commands: 

Get all the nodes in the cluster: 

```
kubectl get nodes
```

Get the cluster info:

```
kubectl cluster-info
```
Have a question about what one of the resources does?  You can have kubectl explain it to you: 

```
kubectl explain pods
```
### See what's running

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

## Run containers with ```kubectl```

In this section we'll run a few commands to manipulate pods and containers. 

Start up a simple [busybox](https://busybox.net/about.html) deployment by running:

```
kubectl run bb --image=busybox --command -- sleep 3600
```

This command creates 

* A deployment named ```bb```
* A pod that runs with the deployment. 

Check for your self that these are running: 

```
kubectl get deployments
kubectl get pods
```
You'll see there is a deployment named ```bb``` and a pod running called ```bb-<some-random-stuff>```.  

The deployment states the intent of the pods.  By default we only ran one instance of the busybox container.  Let's see what happens when we try to kill it: 

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

You will see another one pop up!  Kubernetes will bring up a new busybox pod.  This is because the run command you ran above created a [deployment](http://kubernetes.io/docs/user-guide/deployments/). 

Take a look at the deployment: 

```
kubectl describe deployment bb
```


You are done!  Go back to the [Main Page](README.md)
