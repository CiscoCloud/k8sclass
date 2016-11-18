# Running Kubernetes

### Goals of this lab
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


------
 Potenitally have a section where they just install nginx as an example (would require exposing service, maybe delete it then do guestbook install?
 
 Additional notes:
- discuss namespaces?
- create some fun labels?
- upgrade a component of the app?
 -----
 
GIVE CREDIT TO GUESTBOOK K8S example!!

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

 cd into the lab3 directory and run the following command to create this deployment in your cluster:
 ```
 

 











