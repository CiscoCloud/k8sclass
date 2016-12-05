# Kubernetes Lifecycles Operations

## 0. Goals of this lab
Now that you have deployed and exposed an application. We can make use of some other kubernetes features. By the end of this lab, you should be comfortable with:

 * resizing an application
 * upgrading an application
 * something else?

## 1. Scale up the frontend
One of the core features of kuberntes is allowing the user to easily scale the application without worrying about the underlying infrastrcuture.

Lets say, you have deployed this popular guestbook application. You are now sharing the link to your guestbook all over the social media sites and are expecting a flood of traffic to your site. It would be logical to scale this application to accomodate the increase in traffic.


Confirm the current deploying, running the command 

```
kubectl describe deployment frontend
```


To scale, the deployment, issue the following command: 

```
kubectl scale deployment frontend --replicas=8
```

You can confirm your application scaled by issuing the describe command again or you can query all of the pods.

```bash
kubectl get pods
```

#### Testing Resilency
One of the benefits of Kubernetes is that it can ensure your application is always running and available. You have already seen how replication sets can be used to ensure a certain number of pods is always running. 

You will now see what happens when there is a failure. Query all the pods that are currently running by issuing ```kubectl get pods```

Take note of the pod that has been up for the least amount of time.

A pod could fail for a number of reasons (network issues, application breaks, bad request, problem on underlying infrastrcuture). If it fails for any of these reasons, Kubernetes will automatically see this and restart the problematic pod. As an example, we can kill a few pods and observe this ourselves.

Issue the command 

```
kubectl delete pod <firstpod_fullname> <secondpod_fullname>
```
Be sure to use the full name of the pod (e.g. frontend-88237173-50t2v)


Go ahead and check to see which pods are running now. It is likely, that in this amount of time kubernetes has already started up the pods you just deleted. Notice the new pods that have been up for the least amount of time. From this view we can also see if pods were restarted by Kubernetes. 

You are done!  [Go back to main class page](README.md)
