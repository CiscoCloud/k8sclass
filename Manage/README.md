# Managing Kubernetes Cluster
Now you should have your kubernetes cluster set up and configured.  We are now going to start using Kubernetes like a normal user would to start our applications. 

## SSH Tunnel
Kubernetes does not expose the web interface and command line interface without a certificate.  We can use an SSH tunnel to get around this.  To make this happen run the following command: 

```
ssh -f -nNT -L 8080:127.0.0.1:8080 -i ~/.ssh/t5.pem ubuntu@<kubemaster>
```
The command will run and return with no output.  You should now be able to connect with your local kubectl command: 

```
kubectl get nodes
```
You can also see the pods that are running

```
kubectl get pods --all-namespaces
```
