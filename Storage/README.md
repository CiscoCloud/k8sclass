# Storage

Kubernetes can attach a pod to a persistent storage so that in the event a container goes down the volume lives on.  This is great for databases, or other containers that need persistent storage.  

At this point with the Cinder Driver, kubernetes can take a volume, format it, and mount it to a directory in which you specify.  However, today, it can not create new volumes on the fly.  This should be done in kubernetes 1.5. 

## 1. Create a Volume
In openstack create a cinder volume as follows: 

```
openstack volume create --size 20 voluser<usernumber><initials>
```
eg: ```openstack volume create --size 20 voluser03cc``` so long as the volume name is unique. 

The output will show an ID of the volume.  Make note of this volume id (e.g: ```9ae262a7-3b00-42ed-9f8e-d4cc49f13ba8```)

## 2. Edit the ```nginx.yaml``` file. 



