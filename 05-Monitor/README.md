# Monitor Lab

We want to know the state of our cluster and make sure things stay up!  In this lab we will monitor the status of our cluster. 

## Performance Monitoring

We will start by following the [Heapster Installation Guide](https://github.com/kubernetes/heapster/blob/master/docs/influxdb.md) with some changes due to Metacloud. 

get Heapster: 


```
cd 
git clone https://github.com/kubernetes/heapster.git
cd heapster
```
Install several components

```
kubectl create -f deploy/kube-config/influxdb/
```

This will create 3 pods, ```heapster```, ```graphana```, and ```influxdb```.  

Ensure they are up: 

```
kubectl get pods -n kube-system -o wide
NAME                                    READY     STATUS    RESTARTS   AGE       IP           NODE
heapster-2193675300-nktsw               1/1       Running   0          1m        10.210.1.3   vkw02
kube-dns-v20-1485703853-ah43b           3/3       Running   16         13h       10.210.0.2   vkw01
kube-dns-v20-1485703853-zmg5k           3/3       Running   0          13h       10.210.2.2   vkw03
kubernetes-dashboard-3203700628-x8mgw   1/1       Running   12         13h       10.210.1.2   vkw02
monitoring-grafana-927606581-wvgos      1/1       Running   0          1m        10.210.2.3   vkw03
monitoring-influxdb-3276295126-kalzd    1/1       Running   0          1m        10.210.0.3   vkw01
```

Now make sure our load balancer is pointing to this service. 

```
kubectl edit -n kube-system svc monitoring-grafana
```
This will open a VI session.  Modify ```nodePort: XXXX``` to be ```nodePort: 30861```

This has been previously set up on the nginx cluster to reverse proxy to this port.  Now you should be able to access your load balancer on port ```3000``` to see the grafana data. 

## Log Monitoring

### 1.  Install Fluentd DaemonSet

[fluentd](https://fluentd.io) is used for collecting container logs.  

Run: 

```
kubectl apply -f https://raw.githubusercontent.com/CiscoCloud/k8sclass/master/05-Monitor/fluentd-elasticsearch-v1-daemonset.yaml
```

This creates a [Daemon Set](http://kubernetes.io/docs/admin/daemons/) which is essentially policy that states one pod of will run on every worker node in the cluster. 

### 2.  Install Elastisearch

We follow the guide shown in the [Kuberenetes production cluster examples](https://github.com/kubernetes/kubernetes/tree/master/examples/elasticsearch/production_cluster) with some modifications to make it work on our cluster. 

Run the following commands: 

```
kubectl -f  
```

## Sources

[fluentd daemon set](https://gist.github.com/colemickens/68cc04a19ed834c3f038cba0959e9e40)

## Troubleshooting

Create busybox host to test records.  Make a yaml file called bb.yaml:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  namespace: default
spec:
  containers:
  - image: busybox
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
    name: busybox
  restartPolicy: Always
```
Now run this: 

```
kubectl apply -f bb.yaml
```

Now to log into it: 

```
kubectl exec -it busybox -- /bin/sh
```
That will put you on the shell to run commands. 

To see all the name spaces we have: 
```
kubectl get svc,pods,deployments,daemonset --all-namespaces
```
