# Running Kubernetes

### Goals of this lab04-Running
You will be familiar of basic operations with Kubernetes including deploying applications, scaling them, upgrading, etc.

We will use a common guestbook application. The architecture in the end will look like the following:<BR>
<img src="images/guestbookPods.png" width="600" align="center">


This is an ideal application as it contains various components including:

 * a single node deployment
 * a multi-node deployment
 * a replication controller to ensure some components continue to run
 * a web front-end and backend DB
 * test 

#### Check status of environment
First we want to make sure everything is healthy so lets check the status of the cluster. Use kubectl to check the status of your cluster.
 
```bash
user04@lab01:~$ kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok                   
controller-manager   Healthy   ok                   
etcd-0               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"}   
etcd-2               Healthy   {"health": "true"}   

user04@lab01:~$ kubectl get nodes
NAME               STATUS    AGE
cc-kube-worker01   Ready     1d
cc-kube-worker02   Ready     1d
cc-kube-worker03   Ready     1d

user04@lab01:~$ kubectl cluster-info
Kubernetes master is running at https://184.94.251.31
KubeDNS is running at https://184.94.251.31/api/v1/proxy/namespaces/kube-system/services/kube-dns
kubernetes-dashboard is running at https://184.94.251.31/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard
```


As mentioned previously, there are a number of ways to interact with Kubernetes. 

Here are just some ways to interact with Kubernetes:
 * Directly with APIs
 * Via dashboard
 * Using kubectl to run specific commands (install app, scale, etc) (should we do quick example)?
 * Using kubectl to push? files into kubernetes


---- 
GIVE CREDIT TO GUESTBOOK K8S example!!
----

A preferred way involves maintaining yaml/json files in a repository and then easily pushing those files to Kubernetes. This avoids typos and allows for great detail tracking versions of files which can be 
useful to rollback or debug an application.

As such there are a few different ways we could deploy the guestbook application. For example, we could deploy the entire guestbook application including fronend servers, redis master and slaves by deploying a single YAML file! We don't it that easy do we? For this reason, we will deploy each component and walk through it seperately. 

This guestbook is nice as it has many components. Discuss this in some more detail...
Review the diagram at the begining of this lab

 * frontend: a multi-pod deployment with a service in front. This is a nginx web server to access the guestbook.
 * redis-master: a single-pod deployment with a service in front. This is used for persistant storage. 
 * redis-slave: a multi-pod deployment with a service in front. Data from the redis-master is replicated on the slaves

 The frontend will be accessible by anyone on the Internet. The frontend then interacts with the redis-master via javascript redis API calls. 
 
#### Redis-master Deployment 
 
The frontend will be communicating with the redis-master to store and retrieve data.
 
The redis-master deployment file can be found in the lab3/guestbook/ folder.

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: redis-master
  # these labels can be applied automatically 
  # from the labels in the pod template if not set
  # labels:
  #   app: redis
  #   role: master
  #   tier: backend
  #   exercise: lab3
spec:
  # this replicas value is default
  # modify it according to your case
  replicas: 1
  # selector can be applied automatically 
  # from the labels in the pod template if not set
  # selector:
  #   matchLabels:
  #     app: guestbook
  #     role: master
  #     tier: backend
  template:
    metadata:
      labels:
        app: redis
        role: master
        tier: backend
        exercise: lab3
    spec:
      containers:
      - name: master
        image: gcr.io/google_containers/redis:e2e  # or just image: redis
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 6379
```

Examining this deployment file we notice a few things:

 * The kind is set to <b>deployment</b>
 * replicas is set to 1. This means that if the pod dies, an another will automatically be spun up by Kubernetes.
 * There are various labels set.
 * In the container section, it lists the source for the redis image as well as some requests for resources <b>(do we mention this in the presentation)?</b>

cd into the lab3 guestbook directory and run the following command to create this deployment in your cluster:

```bash
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl create -f redis-master-deployment.yaml 
deployment "redis-master" created
```
 We can confirm our redis-master was deployed successfully by running some additional commands:
 
```bash
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl get deployments
NAME           DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
redis-master   1         1         1            1           1m
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl get replicasets
NAME                      DESIRED   CURRENT   READY     AGE
redis-master-2696761081   1         1         1         1m
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl get pods
NAME                            READY     STATUS    RESTARTS   AGE
redis-master-2696761081-luk0y   1/1       Running   0          1m
```

Notice the naming of the deployment, replicaset, and pod. The pod name is the most detailed. By adding this single YAML file we created a deployment which consisted of a replicatset with a single pod.

You can describe this pod to see additional details after it has been deployed.

```yaml
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl describe pods redis-master-2696761081-luk0y
Name:		redis-master-2696761081-luk0y
Namespace:	default
Node:		cc-kube-worker02/192.168.7.204
Start Time:	Sat, 19 Nov 2016 01:30:50 +0000
Labels:		app=redis
		exercise=lab3
		pod-template-hash=2696761081
		role=master
		tier=backend
Status:		Running
IP:		10.234.1.3
Controllers:	ReplicaSet/redis-master-2696761081
Containers:
  master:
    Container ID:	docker://44266106b1f0202cb037a47a77d6bf6380da3b8ecf3b4f18e5062f56c3201204
    Image:		gcr.io/google_containers/redis:e2e
    Image ID:		docker://sha256:e5e67996c442f903cda78dd983ea6e94bb4e542950fd2eba666b44cbd303df42
    Port:		6379/TCP
    Requests:
      cpu:		100m
      memory:		100Mi
    State:		Running
      Started:		Sat, 19 Nov 2016 01:30:51 +0000
    Ready:		True
    Restart Count:	0
    Volume Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-iuhf7 (ro)
    Environment Variables:	<none>
Conditions:
  Type		Status
  Initialized 	True 
  Ready 	True 
  PodScheduled 	True 
Volumes:
  default-token-iuhf7:
    Type:	Secret (a volume populated by a Secret)
    SecretName:	default-token-iuhf7
QoS Class:	Burstable
Tolerations:	<none>
Events:
  FirstSeen	LastSeen	Count	From				SubobjectPath		Type		Reason		Message
  ---------	--------	-----	----				-------------		--------	------		-------
  3m		3m		1	{default-scheduler }				Normal		Scheduled	Successfully assigned redis-master-2696761081-luk0y to cc-kube-worker02
  3m		3m		1	{kubelet cc-kube-worker02}	spec.containers{master}	Normal		Pulled		Container image "gcr.io/google_containers/redis:e2e" already present on machine
  3m		3m		1	{kubelet cc-kube-worker02}	spec.containers{master}	Normal		Created		Created container with docker id 44266106b1f0; Security:[seccomp=unconfined]
  3m		3m		1	{kubelet cc-kube-worker02}	spec.containers{master}	Normal		Started		Started container with docker id 44266106b1f0
```

If you would like to examine the logs for this container, you can do the following:

```yaml
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl get pods
NAME                            READY     STATUS    RESTARTS   AGE
redis-master-2696761081-luk0y   1/1       Running   0          22m
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl logs redis-master-2696761081-luk0y 
CONTENTS OF LOG
```

As it stands, redis-master has been deployed to a single pod which contains an IP. If there is an issue with this pod, the replication controller will ensure that it spins up again. However, it could now spin up in a different pod or even on a different host. This will result in a new IP address. Because we will have other components talking to this, we can create a service so that other components can reach this service via its service name. This ensures that we always have a way to talk to it.

We already have a redis-master-service.yaml for you

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-master
  labels:
    app: redis
    role: master
    tier: backend
    exercise: lab3
spec:
  ports:
    # the port that this service should serve on
  - port: 6379
    targetPort: 6379
  selector:
    app: redis
    role: master
    tier: backend
```

Note this service file is pretty simple. Its kind is a service with a name of <b>redis-master.</b>

Create this service using the command below (similar to how we created the deployment)

```bash
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl create -f redis-master-service.yaml 
service "redis-master" created
```



#### Redis-slave Deployment 

Since we are building a cloudy guestbook, we want to do everything we can do to ensure that our application is resilient across various failures. For this reason, we will create a redis-slave deployment. The data in the redis-master will be synced to the data in the redis-slave deployment.

Similar to the redis-master deployment, we alreadty have a deployment file for the redis-slave.

Examine redis-slave.yaml closely.

Hopefully you noticed a few things:
 * There is a service defined at the top of the file called <b>redis-slave</b>
 * There is also a deployment defined beneath this service
 * Replicas is set to 2 for this. This will ensure that there are always 2 redis-slaves running. 
 * I need to find out why their isn't a replicaset defined here... is it implied?

You are almost a pro at this, go ahead and create the redis-slave service as shown below:

```bash
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl create -f redis-slave.yaml 
service "redis-slave" created
deployment "redis-slave" created
```

Notice how both a service and deployment were both created for us!

Now lets see what pods are running.

```bash
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl get pods
NAME                            READY     STATUS    RESTARTS   AGE
redis-master-2696761081-luk0y   1/1       Running   0          53m
redis-slave-798518109-0o6vc     1/1       Running   0          9m
redis-slave-798518109-q0gjd     1/1       Running   0          9m
```

---
SANITY CHECK: Why doesn't the redis-master show up when I run kubectl get svc -l exercise
my labels don't seem to work :(
---

#### Frontend Deployment 

For this guestbook example, we will use a simple PHP server that is configured to talk to redis-master or redis-slave depending if the action if a read or write. We will deploy 3 nginx web server pods in this environment using the provided ```frontend.yaml```. 

Configure the frontend as shown below:

```bash
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl create -f frontend.yaml 
deployment "frontend" created
```

Confirm that all componenta are up by listing the deployments and replicasets:
```bash
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl get deployment,rs
NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/frontend       3         3         3            3           51s
deploy/redis-master   1         1         1            1           2d
deploy/redis-slave    2         2         2            2           2d
NAME                         DESIRED   CURRENT   READY     AGE
rs/frontend-88237173         3         3         3         51s
rs/redis-master-2696761081   1         1         1         2d
rs/redis-slave-798518109     2         2         2         2d

```

If you have noticed, we have been labeling the various components. Examine the pods based on the tier label we have applied:

```bash
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl get pods -L tier
NAME                            READY     STATUS    RESTARTS   AGE       TIER
frontend-88237173-e1e18         1/1       Running   0          1m        frontend
frontend-88237173-hxphs         1/1       Running   0          1m        frontend
frontend-88237173-odz12         1/1       Running   0          1m        frontend
redis-master-2696761081-luk0y   1/1       Running   0          2d        backend
redis-slave-798518109-0o6vc     1/1       Running   0          2d        backend
redis-slave-798518109-q0gjd     1/1       Running   0          2d        backend
```
These pods should reflect the diagram of the deployment at the begining of this lab.

You may have also noticed that there is no service for the frontend component. A service will be needed in order to access our guetbook.

You can expose the service via the command line by issuing the command ```kubectl expose deployment frontend --port=80 --type=NodePort```

Depending on the environment Kubernetes is running in, there are a number of ways to expose your applications. With some public cloud providers (e.g. Google), you can use a LoadBalancer instead of a NodePort. In this lab, we will expose the service via NodePort and then reconfigure our nginx web server to redirect traffic to this service. 

You just exposed the frontend deployment as a service of type NodePort. To see what port Kubernetes assigned it you can run the command below or check the dashboard under services >> frontend.

```bash
user04@lab01:~/k8sclass/04-Running/guestbook$ kubectl describe service frontend
Name:			frontend
Namespace:		default
Labels:			app=guestbook
			tier=frontend
Selector:		app=guestbook,tier=frontend
Type:			NodePort
IP:			10.32.0.53
Port:			<unset>	80/TCP
NodePort:		<unset>	31245/TCP
Endpoints:		10.234.0.4:80,10.234.1.5:80,10.234.2.3:80
Session Affinity:	None
```

<img src="images/exposeNodePort.png">

In this example, the NodePort is 31245. This means if you access the workers on this port, you should be able to access this service. 
However, in this lab environment, the only node accessible from the Internet is the VM with the public IP assigned to it (the nginX load balanceR). 
Make node of the port in your reference printout.

#### Configure Load Balancer

The frontend guestbook service has now been exposed. In order to access it on port 31245 you will need to do a slight modification to your load balancer.

SSH into the load balancer using your key and public IP address: ```ssh -i ~/.ssh<yourkeyname.pem> ubuntu@<LB_IP>```

Next, change to root and open the nginx conig file.

```bash
ubuntu@cc-nginx01:~$ sudo su -
root@cc-nginx01:~# vi /etc/nginx/nginx.conf 
```

Towards the bottom of the file, you will see the configuratioin on the frontend:

```yaml
        # guestbook service
        upstream guestbook {
                server 192.168.7.205:31245;
                server 192.168.7.204:31245;
        }


        server {
                listen 8888;
                server_name _;
                location / {
                        proxy_pass http://guestbook;
                }
        }
```

In the upstream section, change the server ports from 31245 to your NodePort (see reference sheet). Notice the frontend is already mapped to 8888.

Finally, restart nginx for changes to take effect using the command ``` service nginx restart```

Open a browser to access your guestbook at the URL: http://<LB_IP>:8888

<img src="images/guestbookRunning.png">











