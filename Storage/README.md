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

Get the ```nginx.yaml``` file by running: 

```
wget https://raw.githubusercontent.com/CiscoCloud/k8sclass/master/Storage/nginx.yaml
```
This simple file shows how to mount a volume to the container.  In this case we are using an nginx container to illustrate.  

### volumeMounts

In the ```volumeMounts``` section of the file you will see there is a ```mountPath``` where the volume will be mounted.  The ```name``` is a name that references the ```volumes``` below.  The ```mountPath``` does not need to exist before it is mounted.  For example, the path ```/vol``` doesn't exist on the nginx container so docker creates it.  

### volumes

The ```volumes``` section allows you to specify a name of the volume that must match the name of the ```volumeMount``` name specified above.  After the name you can specify the driver.  We are using [cinder](https://wiki.openstack.org/wiki/Cinder) as this is OpenStack.  

Here is the place you need to edit.  Put the id of the Cinder volume you created above in the ```volumeID```

```
volumeID: <your volume>
```
E.g.: ```volumeID: 9ae262a7-3b00-42ed-9f8e-d4cc49f13ba8```

Notice that you never formatted the volume, you just created it.  We give it the ```fsType: ext4``` and kubernetes will take care of formatting and mounting the drive.  No ```fdisk``` busywork for us today!

Save this file, you are now ready to deploy it!

## 3. Deploy and Log into the container

Deploy the container with: 

```
kubectl create -f nginx.yaml
```
Now log into the container:

```
kubectl get pods | grep nginx
```
Copy the name of this pod.  Now run: 

```
kubectl exec -it <nginx pod name>  -- /bin/sh
```
E.g.: ```kubectl exec -it nginx-3220071054-mcidk -- /bin/sh```. 

You should now be running in the container.  Take a look at the ```/vol``` directory.  

Run:

```
ls /vol
```
you should see a ```lost+found``` directory typical in the root of a mounted volume.  

Run: 

```
mount | grep /vol
```
Here you will see that the volume is mounted of type ext4.  


