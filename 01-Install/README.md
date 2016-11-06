# 01 Installing Kubernetes

In this lab we will be installing Kubernetes on OpenStack.  Many of these steps could be on bare metal, VMware, or GCE and AWS.  They could also use various installers that are populor today including [kops](https://github.com/kubernetes/kops) or [kube-aws](https://github.com/coreos/coreos-kubernetes/releases)

Instead we will be modeling our installation based on [Kelsey Hightower's Kubernetes the Hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way) as this is more illustrative of the components used and has less mystery. 

Because we don't want to spend all day just installing, we have made Terraform scripts to accomplish the installation.  

To begin, we will be modifying the Terraform script to make it unique to your user team. 

## 1.  Find the Terraform Directory

```
cd ~/k8sclass/01-Install/02-Infrastructure-Prod/Terraform/
```
Here you will find a few scripts, templates, and the  ```metacloud.tf``` file.  Open this file with your favorite text editor and we will change some values to deploy the cluster. 

## Node Unique Names

Change the names to something unique for: 

*   ```master_name```
*    ```lb_name```
*    ```worker_name``` 

This may be a combination of first initials that you can see, or a fun code word like ```dragon-controller``` or something.  As an example it should look something like this: 

```
variable lb_name { default = "fonzi-lb"}
variable master_name { default = "fonzi-controller"}
variable worker_name { default = "fonzi-worker" }
```
(note these variable definitions are not consecutive in the file and are only defined once near the top. 

## OpenStack info

You'll first need to gather some data as to what variables we can use for configuring our Cluster on OpenStack. 



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
export KEYNAME=<somekeyname>
openstack keypair create $KEYNAME | tee ~/.ssh/$KEYNAME.pem
chmod 0600 ~/.ssh/$KEYNAME.pem
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
If this fails then check what variables might need to be changed, or rerun the configuration again.  It should finish cleanly.  If not, please see your instructor for help. 

When this builds cleanly you are ready to go to the next lab and configure kubernetes. 