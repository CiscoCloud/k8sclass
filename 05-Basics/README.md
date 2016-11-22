# 5. Kubernetes Basics

### Goals of this lab
Now that you have deployed and exposed an application. We can make use of some other kubernetes features. By the end of this lab, you should be comfortable with:

 * resizing an application
 * upgrading an application
 * something else?

#### Scale up the frontend
One of the core features of kuberntes is allowing the user to easily scale the application without worrying about the underlying infrastrcuture.

Lets say, you have deployed this popular guestbook application. You are now sharing the link to your guestbook all over the social media sites and are expecting a flood of traffic to your site. It would be logical to scale this application to accomodate the increase in traffic.

Confirm the current deploying, running the command ```kubectl decribe deployment frontend```

To scale, the deployment, issue the following command: ```kubectl scale deployment frontend --replicas=8```

You can confirm your application scaled by issueing the describe command again or you can query all of the pods.

```bash
user04@lab01:~/k8sclass/03-Config$ kubectl get pods
NAME                            READY     STATUS    RESTARTS   AGE
frontend-88237173-1dnyu         1/1       Running   0          32s
frontend-88237173-e1e18         1/1       Running   0          1h
frontend-88237173-hxphs         1/1       Running   0          1h
frontend-88237173-jismn         1/1       Running   0          32s
frontend-88237173-k1dtm         1/1       Running   0          32s
frontend-88237173-odz12         1/1       Running   0          1h
frontend-88237173-vb1mm         1/1       Running   0          32s
frontend-88237173-ywfgw         1/1       Running   0          32s
redis-master-2696761081-luk0y   1/1       Running   0          2d
redis-slave-798518109-0o6vc     1/1       Running   0          2d
redis-slave-798518109-q0gjd     1/1       Running   0          2d
```

