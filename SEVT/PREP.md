# Prep for SEVT

* Deploy the 3 user machines
* Create cluster

## Deploy user machines

Log in and make them have 21 user accounts.  We used xlarge 
```
for i in $(seq -w 1 21); do useradd -m -p $(openssl passwd -1 Cisco.123) -s /bin/bash user$i; done
```

## Copy the ```ca.pem```
Make sure each lab machine has the ```ca.pem``` file in the ```/tmp/``` directory so users can get it as part of the kubectl lab. 

## Expose IP adddresses

Expose 2 or 3 of the workers with floating IP addressess so students can access their guestbook applications. 