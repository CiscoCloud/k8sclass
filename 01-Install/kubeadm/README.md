# Kubernetes Installation Methods 

This is a method we use to install Kubernetes on Metacloud

## Requirements
* Packer version 0.10.2
* Terraform version 0.7.5

## kubeadm 
kubeadm is new in Kubernetes 1.4 and is the easiest way to bring up a quick kubernetes cluster.  At the time of this writing, however, it is still in alpha, though it works pretty well.  It provides a two step way to install kubernetes.  We've made it easy and reproducible to use in our environment with Packer and Terraform. 


### Step 1 Packer

We first build a base image with all the packages we need to run Kubernetes in OpenStack.  Terraform will then use this base image for all the nodes in the Kubernetes cluster.

The ```kube_ubuntu.json``` file found in the Install/Packer directory can be used to deploy an image.  Change the environment variables to create your image as indicated by the instructor.  When you are satisfied with the changes run: 

```
packer build kube_ubuntu.json
```
By adding more packer builders you can build this image in other clouds.  

#### Troubleshooting

Generally issues with Packer will be openstack environment variables or other variables that may not be found.  

### Step 2 Terraform


## Overall Requirements

* use a file to bring up number of nodes
* change the file to bring up more masters
* change the file to add cluster nodes
* use kubeadm to show a quick cluster
* do a more robust version that handles this. 
