# Monitor Lab

We want to know the state of our cluster and make sure things stay up!  In this lab we will monitor the status of our cluster. 

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


## Sources

[fluentd daemon set](https://gist.github.com/colemickens/68cc04a19ed834c3f038cba0959e9e40)

