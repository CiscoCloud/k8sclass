# Metacloud kubernetes setup.  This terraform file should be able to bring up a kubernetes
# cluster up.  We base most of this script on the extremely helpful kubernetes the hard way
# repo from Kelsey Hightower: 
#   https://github.com/kelseyhightower/kubernetes-the-hard-way/tree/master/docs
# while there are many ways to set up kubernetes this seems to work well and give a deep 
# understanding of the way it is set up.  

# There are several improvements we can make in the future including using containers to 
# install the kube components instead of the actual binaries but this works well and is
# something that can be run on bare metal as well with perhaps some modifications. 

## Node Types/Names/Quantities Variables

# These are the names of the servers you want for our cluster.  This is what shows 
# up in Openstack as the hostnames. 
# This also includes the quantities.  3 controllers gives redundancy and is a safe pick. 
# for the workers pick as many as you have room for.  
variable lb_name { default = "vnginx"}
variable lb_count { default = "1" }
variable master_name { default = "vcontroller"}
variable master_count { default = "3" }
variable worker_name { default = "vworker" }
variable worker_count { default = "3" }
variable count_format { default = "%02d" } #server number format (01, 02, ...)

## OpenStack Variables

# these variables are specific to your OpenStack cluster. 
# should be Ubuntu 16.04 and reasonable size. 

variable ssh_user { default = "ubuntu" }  # what is the user name that should be used to log into the nodes? 
variable network { default = "pipeline" } # what openstack network do we use? 
variable kube_image { default = "ubuntu_1604_server_cloudimg_amd64"} # what image do we use? 
variable kube_flavor { default = "m1.large" } # the flavor of the machines.  
variable key_pair { default = "t5" } # what is the keypair name to use?  This should already have been created. 
variable private_key_file { default = "~/.ssh/t5.pem"} # the location of your private key. 
variable security_group { default = "default" } # openstack security group to use. 
variable ip_pool { default = "PUBLIC DO NOT MODIFY" } # the pool of floating IP addresses. 

# sample for Trial 14
#variable network { default = "twenty" } # what openstack network do we use? 
#variable kube_image { default = "Ubuntu16.04"} # what image do we use? 
#variable ip_pool { default = "PUBLIC EXTERNAL - DO NOT MODIFY" } # the pool of floating IP addresses. 
#variable key_pair { default = "k14" } # what is the keypair name to use?  This should already have been created. 
#variable private_key_file { default = "~/.ssh/k14.pem"} # the location of your private key. 

## Kubernetes Variables

# these variables are used to tweek your cluster. 
variable kube_token { default = "f00bar.f00barf00bar1234" } # pick a token that can be used to log into the cluster. 
variable cluster_name { default = "mykubernetes" } # name of your kubernetes cluster. 
variable cluster_domain {default = "cluster.local" } # the internal Kube cluster domain. 

# each kube worker will get assigned a /24 network from this cluster_cidr network.  so if
# we use 10.200.0.0/16 then worker01 will get 10.200.0.0/24, worker02: 10.200.1.0/24, etc. 
# then static host routes need to be configured for the nodes to forward traffic to the worker nodes
# to resolve this IP range. 
variable cluster_cidr {default = "10.201.0.0/16" }

# The service cluster should not overlap with the cluster_cidr and is the network all services
# will be constructed from.  
variable service_cluster_net { default = "10.32.0.0/24"}

# This IP is the main IP that all kube-proxies will route service requests to for services. 
variable service_cluster_ip { default = "10.32.0.1" } # cluster IP used by the servers. 

# cluster DNS has to be an IP address in the cluster network. 
variable cluster_dns {default = "10.32.0.10"}


provider "openstack" {
}

# we only need one floating IP address per load balancer.  The rest of the cluster sits
# behind a firewall until we figure out how to do routing to our applications. 

resource "openstack_compute_floatingip_v2" "fip" {
  pool = "${var.ip_pool}"
  count = "${var.lb_count}"
}

# the load balancers.  This is just ubuntu running nginx to reverse proxy. 

resource "openstack_compute_instance_v2" "lb" {
  name = "${var.lb_name}${format(var.count_format, count.index+1) }"
  count = "${var.lb_count}"
  image_name = "${var.kube_image}"
  flavor_name = "${var.kube_flavor}"
  metadata {
    kube_role = "lb"
  }
  network { 
    name = "${var.network}"
    floating_ip = "${ element(openstack_compute_floatingip_v2.fip.*.address, count.index)}"
  }
  key_pair = "${var.key_pair}" 
  security_groups = ["${var.security_group}"]
}

# kube master nodes.  There should be at least three. 
resource "openstack_compute_instance_v2" "kube-master" {
  name = "${var.master_name}${format(var.count_format, count.index+1) }"
  count = "${var.master_count}"
  image_name = "${var.kube_image}"
  flavor_name = "${var.kube_flavor}"
  metadata {
    kube_role = "master"
  }
  network { 
    name = "${var.network}"
  }
  key_pair = "${var.key_pair}" 
  security_groups = ["${var.security_group}"]
}

# kube workers.  3 or more is a good minimum number. 
resource "openstack_compute_instance_v2" "kube-worker" {
  name = "${var.worker_name}${format(var.count_format, count.index+1) }"
  count = "${var.worker_count}"
  image_name = "${var.kube_image}"
  flavor_name = "${var.kube_flavor}"
  metadata {
    kube_role = "worker"
  }
  network { 
    name = "${var.network}"
  }
  key_pair = "${var.key_pair}" 
  security_groups = ["${var.security_group}"]
}


data "template_file" "nginx" {
  template = "${file("templates/nginx.conf.tpl")}"
  vars {
    server1 = "${openstack_compute_instance_v2.kube-master.0.access_ip_v4}"
    server2 = "${openstack_compute_instance_v2.kube-master.1.access_ip_v4}"
    server3 = "${openstack_compute_instance_v2.kube-master.2.access_ip_v4}"
  }
}

# the template file we use to create the cert files used for security. 
data "template_file" "kubernetes-csr" {
  template = "${file("templates/kubernetes-csr.json.tpl")}"
  vars {
    cluster_ip = "${var.service_cluster_ip}"
    public_ip = "${openstack_compute_instance_v2.lb.0.network.0.floating_ip}"
    master_nodes = "${join(",\n" , formatlist("|%s|,\n|%s|", openstack_compute_instance_v2.kube-master.*.name, openstack_compute_instance_v2.kube-master.*.network.0.fixed_ip_v4))}"
    worker_nodes = "${join(",\n" , formatlist("|%s|,\n|%s|", openstack_compute_instance_v2.kube-worker.*.name, openstack_compute_instance_v2.kube-worker.*.network.0.fixed_ip_v4))}"
  }
}

output "certs" {
  value = "${data.template_file.kubernetes-csr.rendered}"
}


# generate the certificates
# we assume you have cfssljson and cfssl installed.  Otherwise this will fail. 
# see: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-certificate-authority.md
resource "null_resource" "certs12" {
  depends_on = ["openstack_compute_instance_v2.lb","openstack_compute_instance_v2.kube-worker","openstack_compute_instance_v2.kube-master"]
  triggers {
    template = "${data.template_file.kubernetes-csr.rendered}"
  }

  provisioner "local-exec" {
    command = "mkdir -p certs && cp templates/ca-csr.json templates/ca-config.json certs/"
  }

  provisioner "local-exec" {
    command =  "echo \"${data.template_file.kubernetes-csr.rendered}\" | sed -e 's/|/\"/g' > certs/kubernetes-csr.json" 
  }
  provisioner "local-exec" {
    command = "cd certs; cfssl gencert -initca ca-csr.json | cfssljson -bare ca"
  }
  provisioner "local-exec" {
    command = "cd certs; cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes"
  }
}


# copy the key to the master node. 
resource "null_resource" "lb2" {
  depends_on = ["openstack_compute_instance_v2.lb", "data.template_file.nginx"]

  count = "${var.lb_count}"
  connection {
    type = "ssh"
    user = "${var.ssh_user}"
    private_key = "${file(var.private_key_file)}"
    host = "${element(openstack_compute_instance_v2.lb.*.network.0.floating_ip, count.index)}"
  }

  provisioner "file" {
    content = "${data.template_file.nginx.rendered}"
    destination = "nginx.conf"
  }

  provisioner "file" {
    source = "${var.private_key_file}"
    destination = "/home/ubuntu/t5.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get -y install nginx",
      "sudo mv nginx.conf /etc/nginx/",
      "sudo systemctl restart nginx",
      "chmod 0400 /home/ubuntu/t5.pem"
    ]
  }
}

data "template_file" "etcd" {
  count = "${var.master_count}"
  template = "${file("templates/etcd.service.tpl")}"
  vars {
    hostname = "${element(openstack_compute_instance_v2.kube-master.*.name, count.index)}"
    hostip = "${element(openstack_compute_instance_v2.kube-master.*.network.0.fixed_ip_v4, count.index)}" 
    cluster = "${join("," , formatlist("%s=https://%s:2380", openstack_compute_instance_v2.kube-master.*.name, openstack_compute_instance_v2.kube-master.*.network.0.fixed_ip_v4))}"
  }
}


# get hosts file to the nodes. 
resource "null_resource" "hosts" {
  count = "${var.master_count + var.worker_count}"
  connection {
    type = "ssh"
    user = "${var.ssh_user}"
    private_key = "${file(var.private_key_file)}"
    host = "${element(concat(openstack_compute_instance_v2.kube-master.*.access_ip_v4, openstack_compute_instance_v2.kube-worker.*.access_ip_v4, openstack_compute_instance_v2.lb.*.access_ip_v4), count.index)}"
    bastion_host = "${openstack_compute_instance_v2.lb.0.network.0.floating_ip}"
    bastion_key = "${file(var.private_key_file)}"
  }  
  provisioner "local-exec" {
    command = "./terraform.py --hostfile | sed 's/^## begin.*/127.0.0.1 localhost/' >hostfile"
  }
  provisioner "file" {
    source = "hostfile"
    destination = "hostfile"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv hostfile /etc/hosts"
    ]
  }
}


# copy the keys to all the nodes in the cluster. 
resource "null_resource" "etcd" {
  #depends_on = ["null_resource.lb"]

  count = "${var.master_count}"
  connection {
    type = "ssh"
    user = "${var.ssh_user}"
    private_key = "${file(var.private_key_file)}"
    host = "${element(openstack_compute_instance_v2.kube-master.*.access_ip_v4, count.index)}"
    bastion_host = "${openstack_compute_instance_v2.lb.0.network.0.floating_ip}"
    bastion_key = "${file(var.private_key_file)}"
  }  

  # copy key files
  provisioner "file" {
    source = "certs/ca.pem"
    destination = "ca.pem"
  }

  provisioner "file" {
    source = "certs/kubernetes-key.pem"
    destination = "kubernetes-key.pem"
  }

  provisioner "file" {
    source = "certs/kubernetes.pem"
    destination = "kubernetes.pem"
  }
  
  provisioner "file" {
    content = "${element(data.template_file.etcd.*.rendered, count.index)}"
    destination = "etcd.service"
  }

  # put the files in place and get etcd working
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/etcd/",
      "sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/",
      "rm -rf etcd-v3*",
      "wget --quiet https://github.com/coreos/etcd/releases/download/v3.0.10/etcd-v3.0.10-linux-amd64.tar.gz",
      "tar zxvf etcd-v3.0.10-linux-amd64.tar.gz",
      "sudo mv etcd-v3.0.10-linux-amd64/etcd* /usr/bin/",
      "sudo mkdir -p /var/lib/etcd",
      "sudo mkdir -p /etc/systemd/system",
      "sudo cp etcd.service /etc/systemd/system",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable etcd",
      "sudo systemctl start etcd"
    ]
  }
}

# template file for kubernetes-api server
data "template_file" "kube-apiserver" {
  count = "${var.master_count}"
  template = "${file("templates/kube-apiserver.service.tpl")}"
  vars {
    count = "${var.master_count}"
    hostname = "${element(openstack_compute_instance_v2.kube-master.*.name, count.index)}"
    hostip = "${element(openstack_compute_instance_v2.kube-master.*.network.0.fixed_ip_v4, count.index)}" 
    cluster = "${join("," , formatlist("https://%s:2379", openstack_compute_instance_v2.kube-master.*.network.0.fixed_ip_v4))}"
    service_cluster_ip_range = "${var.service_cluster_net}"
    service_port_range = "30000-32767"
  }
}

# template file for kubernetes conteroller manager
data "template_file" "kube-controller-manager" {
  count = "${var.master_count}"
  template = "${file("templates/kube-controller-manager.service.tpl")}"
  vars {
    hostip = "${element(openstack_compute_instance_v2.kube-master.*.network.0.fixed_ip_v4, count.index)}" 
    cluster_cidr = "10.200.0.0/16"
    service_cluster_ip_range = "${var.service_cluster_net}" # has to match the cluster ip range in kube-apiserver
    cluster_name = "${var.cluster_name}"
  }
}

data "template_file" "kube-scheduler" {
  count = "${var.master_count}"
  template = "${file("templates/kube-scheduler.service.tpl")}"
  vars {
    hostip = "${element(openstack_compute_instance_v2.kube-master.*.network.0.fixed_ip_v4, count.index)}" 
  }
}

data "template_file" "kube-tokens" {
  count = "${var.master_count}"
  template = "${file("templates/token.csv.tpl")}"
  vars {
    token = "${var.kube_token}"
  }
}

resource "null_resource" "kube-master" {
  depends_on = ["null_resource.etcd"]

  count = "${var.master_count}"
  connection {
    type = "ssh"
    user = "${var.ssh_user}"
    private_key = "${file(var.private_key_file)}"
    host = "${element(openstack_compute_instance_v2.kube-master.*.access_ip_v4, count.index)}"
    bastion_host = "${openstack_compute_instance_v2.lb.0.network.0.floating_ip}"
    bastion_key = "${file(var.private_key_file)}"
  }  

  provisioner "file" {
    content = "${element(data.template_file.kube-apiserver.*.rendered, count.index)}"
    destination = "kube-apiserver.service"
  }

  provisioner "file" {
    content = "${element(data.template_file.kube-controller-manager.*.rendered, count.index)}"
    destination = "kube-controller-manager.service"
  }

  provisioner "file" {
    content = "${element(data.template_file.kube-scheduler.*.rendered, count.index)}"
    destination = "kube-scheduler.service"
  }

  provisioner "file" {
    content = "${element(data.template_file.kube-tokens.*.rendered, count.index)}"
    destination = "token.csv"
  }

  provisioner "file" {
    source = "templates/authorization-policy.jsonl"
    destination = "authorization-policy.jsonl"
  }
  

  # get the kubernetes binaries
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/kubernetes",
      "sudo cp ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/",
      "wget --quiet https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kube-apiserver",
      "wget --quiet https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kube-controller-manager",
      "wget --quiet https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kube-scheduler",
      "wget --quiet https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kubectl",
      "chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl",
      "sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/bin/" 
    ]
  }  

  # copy the config files to the right place. 
  provisioner "remote-exec" {
    inline = [
      "sudo mv token.csv /var/lib/kubernetes/",
      "sudo mv authorization-policy.jsonl /var/lib/kubernetes/",
      "sudo mv kube-apiserver.service /etc/systemd/system/",
      "sudo mv kube-controller-manager.service /etc/systemd/system/",
      "sudo mv kube-scheduler.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable kube-apiserver",
      "sudo systemctl enable kube-controller-manager",
      "sudo systemctl enable kube-scheduler",
      "sudo systemctl restart kube-apiserver",
      "sudo systemctl restart kube-controller-manager",
      "sudo systemctl restart kube-scheduler"
    ]
  }  
}

data "template_file" "kubelet" {
  count = "${var.worker_count}"
  template = "${file("templates/kubelet.service.tpl")}"
  vars {
    api_servers = "${join("," , formatlist("https://%s:6443", openstack_compute_instance_v2.kube-master.*.network.0.fixed_ip_v4))}"
    cluster_dns = "${var.cluster_dns}"
    cluster_domain = "${var.cluster_domain}"
  }
}

data "template_file" "kubeconfig" {
  count = "${var.worker_count}"
  template = "${file("templates/kubeconfig.tpl")}"
  vars {
    master = "${format("https://%s:6443", openstack_compute_instance_v2.kube-master.0.access_ip_v4)}"
    token = "${var.kube_token}"
  }
}

data "template_file" "kube-proxy" {
  count = "${var.worker_count}"
  template = "${file("templates/kube-proxy.service.tpl")}"
  vars {
    # should make this the load balancer, but for now its the first kube master
    # if going directly to server its https://%s:6443, but if we use 
    # the load balancer instead its just https://%s
    master = "${format("https://%s:6443", openstack_compute_instance_v2.lb.0.access_ip_v4)}"
  }
}

resource "null_resource" "kube-workers" {
  depends_on = ["null_resource.kube-master"]

  count = "${var.worker_count}"
  connection {
    type = "ssh"
    user = "${var.ssh_user}"
    private_key = "${file(var.private_key_file)}"
    host = "${element(openstack_compute_instance_v2.kube-worker.*.access_ip_v4, count.index)}"
    bastion_host = "${openstack_compute_instance_v2.lb.0.network.0.floating_ip}"
    bastion_key = "${file(var.private_key_file)}"
  }
  # copy key files
  provisioner "file" {
    source = "certs/ca.pem"
    destination = "ca.pem"
  }

  provisioner "file" {
    source = "certs/kubernetes-key.pem"
    destination = "kubernetes-key.pem"
  }

  provisioner "file" {
    source = "certs/kubernetes.pem"
    destination = "kubernetes.pem"
  }
  
  # get the Docker file
  provisioner "file" {
    source = "templates/docker.service"
    destination = "docker.service"
  }

  # get the Kubelet file to the worker nodes
  provisioner "file" {
    content = "${element(data.template_file.kubelet.*.rendered, count.index)}"
    destination = "kubelet.service"
  }

  # get the kubeconfig
  provisioner "file" {
    content = "${element(data.template_file.kubeconfig.*.rendered, count.index)}"
    destination = "kubeconfig"
  }

  # get the kube proxy
  provisioner "file" {
    content = "${element(data.template_file.kube-proxy.*.rendered, count.index)}"
    destination = "kube-proxy.service"
  }


  # install certs and docker. 
  provisioner "remote-exec" {
    inline = [
      "sudo apt install bridge-utils",
      "sudo mkdir -p /var/lib/kubernetes",
      "sudo mkdir -p /var/lib/kubelet",
      "sudo mkdir -p /opt/cni",
      "sudo cp ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/",
      "wget --quiet https://get.docker.com/builds/Linux/x86_64/docker-1.12.1.tgz",
      "wget --quiet https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kubectl",
      "wget --quiet https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kube-proxy",
      "wget --quiet https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kubelet", 
      "wget --quiet https://storage.googleapis.com/kubernetes-release/network-plugins/cni-07a8a28637e97b22eb8dfe710eeae1344f69d16e.tar.gz",
      "chmod +x kubectl kube-proxy kubelet",
      "sudo tar -xvf cni-07a8a28637e97b22eb8dfe710eeae1344f69d16e.tar.gz -C /opt/cni", 
      "tar -xvf docker-1.12.1.tgz",
      "sudo cp docker/docker* /usr/bin/",
      "sudo mv kubeconfig /var/lib/kubelet/",
      "sudo mv kubectl kube-proxy kubelet /usr/bin",
      "sudo mv docker.service /etc/systemd/system/",
      "sudo mv kubelet.service /etc/systemd/system/",
      "sudo mv kube-proxy.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable docker",
      "sudo systemctl enable kubelet",
      "sudo systemctl enable kube-proxy",
      "sudo systemctl restart docker",
      "sudo systemctl restart kubelet",
      "sudo systemctl restart kube-proxy"
    ]
  }
}  
