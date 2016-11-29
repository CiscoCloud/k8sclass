# Kubernetes Class

This repository contains the labs and scripts for a Cisco Kubernetes class offered by Cisco.

## Summary
After taking this class, attendees will feel comfortable with the following Kubernetes topics: 

*  Metacloud - Basic intro to the OpenStack solution which Kubernetes run on top of
*  Kubernetes components
*  Deploying Kubernetes
*  Basics of Kubernetes 
*  Deploying/scaling apps in Kubernetes

Additionally, hands-on labs will provide real world experience with Kubernetes.  

**DISCLAIMER** Many Kubernetes tutorials use GCE or AWS.  This material uses OpenStack, specifically, Cisco's OpenStack offering, [Metacloud](http://www.cisco.com/c/en/us/products/cloud-systems-management/metacloud/index.html). 

It is recommended to first print the [Reference](/reference.md) page. This way you can record some variables you set for later use in the labs. 

## Labs

* [Reference](reference.md) - Start by printing this for your reference
* [00 -Metacloud Introduction](00-Metacloud/README.md) - This lab covers a basic overview of Metacloud.
* [01 Environment Setup](01-Setup/README.md) - This lab covers setting up your lab VM for the rest of the labs  
* [02 Installation Lab](02-Install/README.md) - This lab covers installing Kubernetes.  We use a Terraform script to bring it up quickly.  Its done on Metacloud. 
* [03 Configuration Lab](03-Config/README.md) - This lab covers getting ```kubectl``` configured to work with our lab environment as well as the final touches of networking required to make our kubernetes cluster functional.  
* [04 Running Kubernetes](04-Running/README.md) - This lab covers deploying and managing applications in our operational kubernetes environment.
* [05 Kubernetes ops](05-Basics/README.md) - This lab covers some additional basic operations in Kubernetes.
* [CI/CD Lab](06-CICD/README.md) - WIP
* [Monitoring](07-Monitor/README.md) - WIP



