# Kubernetes Class

This repository contains the labs and scripts for a Cisco Kubernetes class offered by Cisco.

## Summary
After taking this class, attendees will feel comfortable with the following Kubernetes topics: 

*  Kubernetes components
*  Deploying Kubernetes
*  Basics of Kubernetes 
*  Deploying/scaling apps in Kubernetes

Additionally, hands-on labs will provide real world experience with Kubernetes.  

__DISCLAIMER__ Many Kubernetes tutorials use GCE or AWS.  This material uses OpenStack, specifically, Cisco's OpenStack offering named [Metacloud](http://www.cisco.com/c/en/us/products/cloud-systems-management/metacloud/index.html). 

It is recommended to first print the [Reference](/reference.md) page. This way you can record some variables you set for later use in the labs. 

## Labs

* [Environment Setup](00-Setup/README.md) - This lab covers setting up your workstation or logging into our lab machines to get started.  
* [Metacloud Introduction](01-Metacloud/README.md) - This lab covers installing Kubernetes.  We use a Terraform script to bring it up quickly.  Its done on Metacloud.
* [Installation Lab](02-Install/README.md) - This lab covers installing Kubernetes.  We use a Terraform script to bring it up quickly.  Its done on Metacloud. 
* [Configuration Lab](03-Config/README.md) - This lab covers getting ```kubectl``` configured to work with our lab environment as well as the final touches of networking required to make our kubernetes cluster functional.  
* [Running Kubernetes](04-Running/README.md) - This lab covers deploying and managing applications in our operational kubernetes environment. 
* [CI/CD Lab](05-CICD/README.md) - WIP
* [Monitoring](06-Monitor/README.md) - WIP



