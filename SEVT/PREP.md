# Prep for SEVT

* Deploy the 3 user machines
* Create cluster

## Deploy user machines

Log in and make them have 21 user accounts.  We used xlarge 
```
for i in $(seq -w 1 21); do useradd -m -p $(openssl passwd -1 Cisco.123) -s /bin/bash user$i; done
```
