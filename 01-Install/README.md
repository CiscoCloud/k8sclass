# Installing Kubernetes

We will be using OpenStack for installing Kubernetes but many of these steps could be on bare metal, VMware, or GCE and AWS.  

We will be modifying some components in the ```metacloud.tf``` file so we can quickly deploy the kubernetes cluster. 

## Node Unique Names

Start by opening up the ```metacloud.tf``` file and change the ```master_name```, ```lb_name```, and ```worker_name``` to something unique.  This may be a combination of first initials that you can see, or a fun code word like ```dragon-controller``` or something. 

## OpenStack info

You'll first need to gather some data as to what variables we can use for configuring our Cluster on OpenStack. 

### Caveats for Liberty OpenStack builds
The following exceptions are noted for using Liberty with Terraform.  The file that is downloaded from the Horizon dashboard will need a few other environment variables set:

```
export OS_AUTH_URL=https://<given url>:5000/v3
export OS_DOMAIN_NAME="<domain name>"
```

### Network

You'll need to know which network your cluster will be deployed on.  This should be assigned.  You can find it by running: 

```
openstack network list
```
From the list of networks make note of which one is used for your environment. This should then be updated in the ```metacloud.tf``` file in this repository. 

e.g. if my network was named "twenty", I would update the file to be:
```
variable network { default = "twenty" } 
```

We need to figure out where the ip pool will come from.  In OpenStack we want to give our public facing nodes a floating IP address so we can connect remotely to that node via ssh.  This will be given to you by the instructor, but should be something like: ```PUBLIC - DO NOT MODIFY```.  Update the ```metacloud.tf``` file with this information.  e.g.:

```
variable ip_pool { default = "PUBLIC EXTERNAL - DO NOT MODIFY" } 
```


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
Next you need to know which flavor to use. 

```
openstack flavor list
```
We will use the ```m1.large```.  Take note of this name or any other name as defined by instructor and update the ```metacloud.tf``` file to include this.  e.g.:

```
variable kube_flavor { default = "m1.large" }
```

### Key 

Kubernetes (and you) will need to access the nodes via ```ssh```.  You can enable this by creating your own key pair.  

Generate a keypair by running: 

```
openstack keypair create <keyname> | tee ~/.ssh/<keyname>.pem
chmod 0600 ~/.ssh/<keyname>.pem
```
where ```<keypair>``` is the name you give your key. Maybe something clever like your name?  Favorite sports team?  Just be sure its unique!

Update the ```metacloud.tf``` file with the new key information.  e.g.:

```
variable key_pair { default = "<keypair>" }
variable private_key_file { default = "~/.ssh/<keypair>.pem"}
```
where ```<keypair>``` is the name you gave it below. 

## Kubernetes Settings

Find the section ```Kubernetes Variables``` after the openstack section near the top of the ```metacloud.tf``` file.  We will modify some variables here. 

#### kube_token
Change this to be something unique.  e.g.: a password. 
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
e.g: ```10.14.0.0/16```

#### service__cluster__net
Leave this as the existing setup. 
#### service_cluster_ip
Leave this as existing setup. 
#### cluster_dns
Leave this as defined. 

