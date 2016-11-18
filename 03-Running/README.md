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


#### Check status of environment
 * have user check health of cluster
 * login to dashboard

As mentioned previously, there are a number of ways to interact with Kubernetes. Recap components?

Here are just some ways to interact with Kubernetes:
 * Directly with APIs
 * Via Dashboard
 * Using kubectl to run specific commands (install app, scale, etc)
 * Using kubectl to push? files into kubernetes

A preferred way involves maintaining yaml/json files in a repository and then neasily pushing those files to Kubernetes. This avoids typos and allows for great details tracking versions of files which can be useful to rollback or debug the application.





