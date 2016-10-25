variable lb_name { default = "knginx"}
variable lb_count { default = "1" }
variable master_name { default = "kcontroller"}
variable master_count { default = "3" }
variable worker_name { default = "kworker" }
variable worker_count { default = "3" }
variable ssh_user { default = "ubuntu" }
variable network { default = "pipeline" }
variable kube_image { default = "ubuntu_1604_server_cloudimg_amd64"}
variable kube_flavor { default = "m1.large" }
variable key_pair { default = "t5" }
variable private_key_file { default = "~/.ssh/t5.pem"}
variable security_group { default = "default" }
variable ip_pool { default = "PUBLIC DO NOT MODIFY" }
variable kube_token { default = "f00bar.f00barf00bar1234" }
variable count_format { default = "%02d" } #server number format (01, 02, ...)
variable cluster_name { default = "mykubernetes" } # name of your kubernetes cluster. 

provider "openstack" {
}

resource "openstack_compute_floatingip_v2" "fip" {
  pool = "${var.ip_pool}"
  count = "${var.lb_count}"
}

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

# copy the key to the master node. 
resource "null_resource" "lb" {
  depends_on = ["openstack_compute_instance_v2.lb"]

  count = "${var.lb_count}"
  connection {
    type = "ssh"
    user = "${var.ssh_user}"
    private_key = "${file(var.private_key_file)}"
    host = "${element(openstack_compute_instance_v2.lb.*.network.0.floating_ip, count.index)}"
  }

  provisioner "file" {
    source = "${var.private_key_file}"
    destination = "/home/ubuntu/t5.pem"
  }

  provisioner "remote-exec" {
    inline = [
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
    host = "${element(concat(openstack_compute_instance_v2.kube-master.*.access_ip_v4, openstack_compute_instance_v2.kube-worker.*.access_ip_v4), count.index)}"
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
  depends_on = ["null_resource.lb"]

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
    service_cluster_ip_range = "10.32.0.0/24"
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
    service_cluster_ip_range = "10.32.0.0/24"  # has to match the cluster ip range in above definition
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
    cluster_dns = "10.32.0.10"
    cluster_domain = "cluster.local"
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
    master = "${format("https://%s:6443", openstack_compute_instance_v2.kube-master.0.access_ip_v4)}"
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
