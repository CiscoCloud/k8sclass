variable master_name { default = "vkube-master"}
variable master_count { default = "1" }
variable worker_name { default = "vkube-worker" }
variable worker_count { default = "2" }
variable ssh_user { default = "ubuntu" }
variable network { default = "pipeline" }
variable kube_image { default = "kube-ubuntu-1476298575"}
variable kube_flavor { default = "m1.large" }
variable key_pair { default = "t5" }
variable security_group { default = "default" }
variable ip_pool { default = "PUBLIC DO NOT MODIFY" }

provider "openstack" {
}

resource "openstack_compute_floatingip_v2" "fip" {
  pool = "${var.ip_pool}"
}

resource "openstack_compute_instance_v2" "kube-master" {
  name = "${var.master_name}"
  count = "${var.master_count}"
  image_name = "${var.kube_image}"
  flavor_name = "${var.kube_flavor}"
  metadata {
    kube_role = "master"
  }
  network { 
    name = "${var.network}"
    floating_ip = "${openstack_compute_floatingip_v2.fip.address}"
  }
  key_pair = "${var.key_pair}" 
  security_groups = ["${var.security_group}"]
  user_data = "${file("master.sh")}"
}

resource "openstack_compute_instance_v2" "kube-worker" {
  depends_on = ["openstack_compute_instance_v2.kube-master"]
  name = "${var.worker_name}"
  count = "${var.worker_count}"
  image_name = "${var.kube_image}"
  flavor_name = "${var.kube_flavor}"
  metadata {
    kube_role = "minion"
  }
  network { 
    name = "${var.network}"
  }
  key_pair = "${var.key_pair}" 
  security_groups = ["${var.security_group}"]
}
