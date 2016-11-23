# 2. Installing Kubernetes

In this lab we will be installing Kubernetes on OpenStack.  Many of these steps could be on bare metal, VMware, or GCE and AWS.  

Additionally, there are much more robust ways to install kubernetes.  Many popular installers are out there today including:

*  [bootkube](https://github.com/kubernetes-incubator/bootkube)
*  [kismatic](https://github.com/kismatic/kubernetes)
*  [kops](https://github.com/kubernetes/kops) 
*  [kube-aws](https://github.com/coreos/coreos-kubernetes/releases)
*  [kubeadm](http://kubernetes.io/docs/getting-started-guides/kubeadm/)

These installers have a bit of magic to them so instead we will be modeling our installation from [Kelsey Hightower's Kubernetes the Hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way) as this is more illustrative of the components used and has less mystery.  While we'll still automate most of it, we'll have a few parts to modify to bring home key concepts. 

We don't want to spend all day installing, so we have made Terraform scripts to accomplish the installation. 

### Goals of this lab
In this lab we will install 7 servers: 

* **1 NGINX load balancer** that we will use to access kubernetes services from the outside by assigning a floating IP to it.  It will also be used to load balance the kubernetes master nodes. By routing all traffic through this front end it also allows us to cut down on the number of floating IPs used in the labs.
* **3 Kubernetes master/controller nodes** will provide high availability for cluster services. 
* **3 Kubernetes worker nodes** also known as minions, these nodes will be where containers actually run on the cluster. 

By the end of this lab, 7 nodes will be running on OpenStack and *almost* be ready to run workloads.  The [next lab](https://github.com/CiscoCloud/k8sclass/blob/master/02-Config/README.md) will then finalize the configuration. The diagram below shows what the resulting setup will look like. Each box represents a virtual machine. Notice that the user communicates through the nginx load balancer. 
![labSetup](images/k8sclass-setup.png)


###  Find the Terraform Directory

Most of this lab will involve modifying a Terraform script that will be used to deploy the nodes.  First, find the terraform script: 

```
cd ~/k8sclass/02-Install/Terraform/
```
(If this directory does not exist you didn't finish the [setup lab!](https://github.com/CiscoCloud/k8sclass/blob/master/00-Setup/README.md)  Go back and run the ```git clone``` command!)

In this directory you will find a few scripts, templates, and the  ```metacloud.tf``` file.  Open this file with your favorite text editor and we will change some values to deploy the cluster. 

### Node Unique Names

Change the names to something unique for: 

*  ```master_name```
*  ```lb_name```
*  ```worker_name``` 

This should be a combination of your initials.  [Captain cloud] (https://twitter.com/captaincloud_uk) completed these labs in record time, so we will commemorate him using his initials, cc.  As an example Captain Cloud's file would contain the following: 

```bash
variable lb_name { default = "cc-lb"}
variable master_name { default = "cc-controller"}
variable worker_name { default = "cc-worker" }
```

**Note 1:** these variable definitions are not consecutive in the file and are only defined once near the top.)  
**Note 2:** It's really important that you make these unique or you will mess up several parts of the lab.  
**Note 3:** Be sure not to use an underscore (_) in the names.

### OpenStack info

Next you'll need to gather some data as to what variables we can use for configuring our kubernetes cluster on OpenStack. These will be added in ```metacloud.tf```.  You may want to open another terminal so you have one terminal to edit the ```metacloud.tf``` file and another terminal to run commands on. 

#### Network

You'll need to know which network your cluster will be deployed on.  Ask the instructor if they haven't told you already (or ask again if you weren't paying attention), or go dangerous and try to find it yourself: 

```openstack network list```

From the list of networks make note of which one is used for your environment.  It will be the same network that the lab VM is on. It will also be the same instance that you put a VM on in lab 0. This should then be updated in the ```metacloud.tf``` file. 

e.g. if my network was named "twenty", I would update the file to be:

```
variable network { default = "twenty" } 
```

Next, you need to figure out which pool the floating IPs will be assigned from.  In OpenStack we want to give our public facing nodes a floating IP address so we can connect remotely to that node via ssh.  This will be given to you by the instructor, but should be something like: ```PUBLIC - DO NOT MODIFY```.  Update the ```metacloud.tf``` file with this information.  e.g.:

```
variable ip_pool { default = "PUBLIC DO NOT MODIFY" } 
```
__Note:__ You may not need to change some of these values as they may already be set correctly. Lucky you! 😀

#### Image Information

We'll need to know which image to use.  In this lab we are looking to use ```Ubuntu 16.04```.  You should be able to find the image corresponding to this OS by running: 

```openstack image list```

Update the ```metacloud.tf``` file to include this image.  e.g.:

```
variable kube_image { default = "Ubuntu16.04"}
```

You should also know what user will log into this image.  Your instructor should be able to tell you this and you can update the ```metacloud.tf``` file with something like: 

```variable ssh_user { default = "ubuntu" }```

Most likely it will just be ```ubuntu``` so leave it at that unless you are told otherwise.  

Next you need to know which flavor to use. The flavor is tied to the amount of resources each VM will use. We will use the same flavor for all of the VMs.

```openstack flavor list``` will list all of the available flavors.

We will use the ```m1.medium``` for this lab.  Take note of this name or any other name as defined by instructor and update the ```metacloud.tf``` file to include this.  e.g.:

```variable kube_flavor { default = "m1.medium" }```

#### Key

Save the ```metacloud.tf``` file to do this next session.  Kubernetes (and you) will need to access the nodes via ```ssh```.  You need to create a key pair that can log into the VMs Terraform's configuration is about to create.  

In cloud systems we use key pairs (public and private keys) to access instances ("instance" is a classy word for a "VM" created in the cloud).  

Generate a keypair by running: 

```bash
export KEYNAME=<somekeyname>
mkdir -p ~/.ssh
openstack keypair create $KEYNAME | tee ~/.ssh/$KEYNAME.pem
chmod 0600 ~/.ssh/$KEYNAME.pem
```

where ```<somekeyname>``` is the name you give your key. Maybe something clever like your name?  Favorite sports team?  Just be sure its unique!

Captain cloud ran the following:

```bash
export KEYNAME=captaincloudskey
mkdir -p ~/.ssh
openstack keypair create $KEYNAME | tee ~/.ssh/$KEYNAME.pem
chmod 0600 ~/.ssh/$KEYNAME.pem
```

When you are finished, edit the ```metacloud.tf``` file with the name of the key you just created.  Update the sections below with the name of your keypair:

```
variable key_pair { default = "<keypair>" }
variable private_key_file { default = "~/.ssh/<keypair>.pem"}
```
where ```<keypair>``` is the name you gave it above. 

### Kubernetes Settings

Find the section ```Kubernetes Variables``` after the OpenStack section near the top of the ```metacloud.tf``` file.  We will modify some variables here. 

#### kube_token
This will be the password for the kubernetes cluster. Make note of it in your reference printout!  This is going to be the token used by components within the Kubernetes cluster to access the API server. 

```
variable kube_token { default = "f00bar.f00barf00bar1234" }
```

#### cluster_name
Change this to be something unique: e.g.: ```captainClouds-cluster```

```
variable cluster_name { default = "mykubernetes" }
```

#### cluster_cidr
This will create a ```/16``` unique network.  The instructor will assign this but it may be something like: 
```10.200+<group#>.0.0/16``` For example, if your group was 4, your network may be something like ```10.204.0.0/16```.

#### cluster_nets_prefix

Change the second octet to reflect the value you put in the cidr field. 

```
variable cluster_nets_prefix {default = "10.204" }
```

#### service__cluster__net
Leave this as defined. 
#### service_cluster_ip
Leave this as defined. 
#### cluster_dns
Leave this as defined. 

## Apply and Build

We will now build the cluster by running: 

```bash
terraform plan
terraform apply
```
If this fails then check what variables might need to be changed or rerun the configuration again.  

**NOTE:**  There may be a bug in the terraform file so it may fail to build the first time (messages relating to certs/ca.pem). Simply running it again should get around this. Extra credit if you can identify the bug! 

It should finish cleanly.  If not, please see your instructor for help. 

After this has built cleanly you are ready to go to the [next lab](https://github.com/CiscoCloud/k8sclass/blob/master/03-Config/README.md) to verify and configure kubernetes. 

**PUT EXAMPLE OUTPUT HERE**?



