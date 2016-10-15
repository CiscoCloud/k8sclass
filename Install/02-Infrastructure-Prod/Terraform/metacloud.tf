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
}

# copy the keys to all the nodes in the cluster. 
resource "null_resource" "kubecluster" {
  
}
