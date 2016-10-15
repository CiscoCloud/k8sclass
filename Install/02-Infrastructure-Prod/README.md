# Production Installation

with Kubeadm it's not quite up to production because it doesn't have redundant master nodes.  We want to have redundant master nodes.  In addition there's a lot of voodoo it does to work.  If we want to understand Kuberentes there is more work to do.  

### Install Kubernetes Nodes

Now we install all the kubernetes nodes 

* 1 nginx load balancer
* 3 controller nodes
* 3 worker nodes

Use the terraform file and run 

```
terraform apply
```
This will install all the nodes

We can get the node list by running the ```terraform.py --hostfile``` command that is included in this directory. 

Alternatively, we can use the ```openstack server list``` command to see the IP addresses assigned to the servers.  

### TLS
To generate certificates for Kubernetes we will follow [Kelsey Hightower's Kubernetes the Hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-certificate-authority.md) instructions with some modifications since we are using OpenStack

#### Get some binaries to get TLS Certs

#####  OSX

```
wget https://pkg.cfssl.org/R1.2/cfssl_darwin-amd64
chmod +x cfssl_darwin-amd64
sudo mv cfssl_darwin-amd64 /usr/local/bin/cfssl
```

```
wget https://pkg.cfssl.org/R1.2/cfssljson_darwin-amd64
chmod +x cfssljson_darwin-amd64
sudo mv cfssljson_darwin-amd64 /usr/local/bin/cfssljson
```

#### Setup Certificate Authority

##### Create the CA configuration file

```
echo '{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}' > ca-config.json
```

##### Generate the CA certificate and private key
CA CSR (Certificate Authority Certificate Signing Request)
```
echo '{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}' > ca-csr.json
```
Now we generate the CA certificate: 
```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```
Results:
```
ca-key.pem
ca.csr
ca.pem
```
Verify:
```
openssl x509 -in ca.pem -text -noout
```

#### Generate the single Kubernetes TLS Cert

We need to get our nginx server as well in this setup:
```
openstack server list
```
Take note of the floating IP address of the nginx server(s)

```
./terraform.py --hostfile | grep -v '#' | awk '{print $1}' 
```

Now we run the following to generate a cert 

```
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "kworker01",
    "kworker02",
    "kworker03",
    "kcontroller01",
    "kcontroller02",
    "kcontroller03",
    "knginx01",
    "10.106.1.8",
	"10.106.1.7",
	"10.106.1.6",
"10.106.1.4",
"10.106.1.5",
"10.106.1.2",
"10.106.1.3",
    "184.94.251.11",
    "127.0.0.1"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Cluster",
      "ST": "Oregon"
    }
  ]
}
EOF
```

Now run: 
```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
```
Now we have several more keys: 
```
kubernetes-key.pem
kubernetes.csr
kubernetes.pem
```
Verify them: 
```
openssl x509 -in kubernetes.pem -text -noout
```
Now we have to get these on all the hosts in our cluster. 


