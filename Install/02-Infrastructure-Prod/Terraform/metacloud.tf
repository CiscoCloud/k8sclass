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
variable token { default = "f00bar.f00barf00bar1234" }
variable count_format { default = "%02d" } #server number format (01, 02, ...)

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

output "rendered" {
  value = "${element(data.template_file.etcd.*.rendered, count)}"
}
