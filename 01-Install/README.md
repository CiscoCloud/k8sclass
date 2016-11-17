# 01 Installing Kubernetes

In this lab we will be installing Kubernetes on OpenStack.  Many of these steps could be on bare metal, VMware, or GCE and AWS.  

Additionally, there are much more robust ways to install kubernetes.  Many popular installers are out there today including:

*  [kops](https://github.com/kubernetes/kops) 
*  [kube-aws](https://github.com/coreos/coreos-kubernetes/releases)
*  [kubeadm](http://kubernetes.io/docs/getting-started-guides/kubeadm/)
*  [bootkube](https://github.com/kubernetes-incubator/bootkube)

These installers have a bit of magic to them so instead we will be modeling our installation from [Kelsey Hightower's Kubernetes the Hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way) as this is more illustrative of the components used and has less mystery.  While we'll still automate most of it, we'll have a few parts to modify to bring home key concepts. 

Because we don't want to spend all day just installing, we have made Terraform scripts to accomplish the installation. 

### Goals of this lab
In this lab we will install 7 servers: 

* __1 NGINX load balancer__ that we will use to access kubernetes services from the outside.  This load balancer will also be used to load balance our kubernetes master nodes. It also allows us to cut down on the amount of floating IPs needed for operating these labs.
* __3 Kubernetes master/controller nodes__  These nodes will provide high availability for cluster services. 
* __3 Kubernetes worker nodes__ Also known as minions, these nodes will be where containers actually run on the cluster. 

By the end of this lab, these 7 nodes will be running on OpenStack and be _mostly_ ready to run workloads.  The [next lab](https://github.com/CiscoCloud/k8sclass/blob/master/02-Config/README.md) will then finalize the configuration. 

## 1.  Find the Terraform Directory

Most of this lab will be modifying a Terraform script that will be used to deploy the nodes.  First, find the terraform script: 

```
cd ~/k8sclass/01-Install/Terraform/
```
(If this directory does not exist you didn't finish the [setup lab!](https://github.com/CiscoCloud/k8sclass/blob/master/00-Setup/README.md)  Go back and run the ```git clone``` command!)

In this directory you will find a few scripts, templates, and the  ```metacloud.tf``` file.  Open this file with your favorite text editor and we will change some values to deploy the cluster. 

## Node Unique Names

Change the names to something unique for: 

*   ```master_name```
*    ```lb_name```
*    ```worker_name``` 

This should be a combination of your intiials.  Captain cloud (https://twitter.com/captaincloud_uk) completed these labs in record time, so we will commemerate him using his initialls, cc.  As an example Captain Cloud's file would contain the following: 

```bash
variable lb_name { default = "cc-lb"}
variable master_name { default = "cc-controller"}
variable worker_name { default = "cc-worker" }
```

__Note 1:__ these variable definitions are not consecutive in the file and are only defined once near the top.) <BR>
__Note 2:__ It's really important that you make these unique or you will mess up several parts of the lab.  <BR>
__Note 3:__ Be sure not to use an underscore (_) in the names  

## OpenStack info

Next you'll need to gather some data as to what variables we can use for configuring our Cluster on OpenStack. Then we will put these values into ```metacloud.tf```.  If you are running on a lab machine, you may want to open another terminal so you have one terminal to edit the ```metacloud.tf``` file and another terminal to run commands on. 

### Network

You'll need to know which network your cluster will be deployed on.  Ask the instructor if they haven't told you already (or ask again if you weren't paying attention), or go dangerous and try to find it yourself: 

```
openstack network list
```

From the list of networks make note of which one is used for your environment.  It will be the same network that the lab machine is on. This should then be updated in the ```metacloud.tf``` file in this repository. 

e.g. if my network was named "twenty", I would update the file to be:
```
variable network { default = "twenty" } 
```

Next you need to figure out where the ip pool will come from.  In OpenStack we want to give our public facing nodes a floating IP address so we can connect remotely to that node via ssh.  This will be given to you by the instructor, but should be something like: ```PUBLIC - DO NOT MODIFY```.  Update the ```metacloud.tf``` file with this information.  e.g.:

```
variable ip_pool { default = "PUBLIC EXTERNAL - DO NOT MODIFY" } 
```
__Note:__ You may not need to change some of these values as they may already be set correctly. Lucky you! 😀

### Image Information

We'll need to know which image to use.  In this lab we are looking to use ```Ubuntu 16.04```.  You should be able to find the image corresponding to this OS by running: 

```
openstack image list
```
Update the ```metacloud.tf``` file to include this image.  e.g.:

```
variable kube_image { default = "Ubuntu16.04"}
```

You should also know what the user is to log into this image.  Your instructor should be able to tell you this and you can update the ```metacloud.tf``` file with something like: 

```
variable ssh_user { default = "ubuntu" }
```
Most likely it will just be ```ubuntu``` so leave it at that unless you are told otherwise.  

Next you need to know which flavor to use. 

```
openstack flavor list
```
We will use the ```m1.large```.  Take note of this name or any other name as defined by instructor and update the ```metacloud.tf``` file to include this.  e.g.:

```
variable kube_flavor { default = "m1.large" }
```

### Key 

Save the ```metacloud.tf``` file to do this next session.  Kubernetes (and you) will need to access the nodes via ```ssh```.  You will need to create a key pair so you can log into the VMs that your terraform configuration is about to create.  

In cloud systems we use key pairs (public and private keys) to access instances ("instance" is a classy word for a "VM" created in the cloud).  

Generate a keypair by running: 

```
export KEYNAME=<somekeyname>
mkdir -p ~/.ssh
openstack keypair create $KEYNAME | tee ~/.ssh/$KEYNAME.pem
chmod 0600 ~/.ssh/$KEYNAME.pem
```
where ```<somekeyname>``` is the name you give your key. Maybe something clever like your name?  Favorite sports team?  Just be sure its unique!

When you are finished, continue editing the ```metacloud.tf``` file with the name of this key you just created.  Update the sections below with the name of your keypair:

```
variable key_pair { default = "<keypair>" }
variable private_key_file { default = "~/.ssh/<keypair>.pem"}
```
where ```<keypair>``` is the name you gave it below. 

## Kubernetes Settings

Find the section ```Kubernetes Variables``` after the openstack section near the top of the ```metacloud.tf``` file.  We will modify some variables here. 

#### kube_token
Change this to be something unique.  e.g.: a password.  This is going to be the token used by components within the Kubernetes cluster to access the API server. 

```
variable kube_token { default = "f00bar.f00barf00bar1234" }
```
#### cluster_name
Change this to be something unique: e.g.: ```joes-cluster```

```
variable cluster_name { default = "mykubernetes" }
```
#### cluster_cidr
Create a ```/16``` unique network.  The instructor will assign this but it may be something like: 
```
10.<group#>.0.0/16
```
e.g: ```10.214.0.0/16```

#### cluster_nets_prefix

Change the first two octets to match the previous entries first two octets. 

```
variable cluster_nets_prefix {default = "10.214" }
```

#### service__cluster__net
Leave this as the existing setup. 
#### service_cluster_ip
Leave this as existing setup. 
#### cluster_dns
Leave this as defined. 

## Apply and Build

We will now build the cluster by running: 

```
terraform plan
terraform apply
```
If this fails then check what variables might need to be changed, or rerun the configuration again.  

__NOTE:__  There may be a bug in the terraform file so it may fail to build the first time (messages relating to certs/ca.pem). Simply running it again should get around this. Exra credit if you can identify the bug! 

It should finish cleanly.  If not, please see your instructor for help. 

When this builds cleanly you are ready to go to the next lab to verify and configure kubernetes. 



