variable master_name { default = "vkube-master"}
variable master_count { default = "1" }
variable worker_name { default = "vkube-worker" }
variable worker_count { default = "2" }
variable ssh_user { default = "ubuntu" }
variable network { default = "pipeline" }
variable kube_image { default = "kube-ubuntu-1476298575"}
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
    floating_ip = "${openstack_compute_floatingip_v2.fip.address}"
  }
  key_pair = "${var.key_pair}" 
  security_groups = ["${var.security_group}"]
}


# go through each master node and run some setup on him. 
resource "null_resource" "master" {
  depends_on = ["openstack_compute_instance_v2.kube-master"]

  count = "${var.master_count}"
  connection {
    type = "ssh"
    user = "${var.ssh_user}"
    private_key = "${file(var.private_key_file)}"
    host = "${element(openstack_compute_instance_v2.kube-master.*.network.0.floating_ip, count.index)}"
  }

  provisioner "file" {
    source = "${var.private_key_file}"
    destination = "/home/ubuntu/t5.pem"
  }

  # bring up the kube master on the master node
  provisioner "remote-exec" {
    inline = [
      #"sudo kubeadm init --token ${var.token}",
      #"sudo kubectl get nodes"
      "sudo kubeadm init --token ${var.token}"
    ]
  }
}

resource "openstack_compute_instance_v2" "kube-worker" {
  depends_on = ["openstack_compute_instance_v2.kube-master", "null_resource.master"]
  name = "${var.worker_name}"
  name = "${var.worker_name}${format(var.count_format, count.index+1) }"
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

# go through each worker node and run some setup on him. 
resource "null_resource" "worker" {
  depends_on = ["openstack_compute_instance_v2.kube-worker"]

  count = "${var.worker_count}"
  connection {
    type = "ssh"
    user = "${var.ssh_user}"
    # we connect to the worker nodes through the master node
    bastion_host = "${openstack_compute_instance_v2.kube-master.0.network.0.floating_ip}"
    bastion_key = "${file(var.private_key_file)}"
    private_key = "${file(var.private_key_file)}"
    host = "${element(openstack_compute_instance_v2.kube-worker.*.access_ip_v4, count.index)}"
  }

  # copy the private key to the master so we can log into the minions 
  provisioner "file" {
    source = "${var.private_key_file}"
    destination = "/home/${var.ssh_user}/key.pem"
  }

  # join the kubernetes cluster
  provisioner "remote-exec" {
    inline = [
      "chmod 400 /home/${var.ssh_user}/key.pem",
      "sudo kubeadm join --token ${var.token} ${openstack_compute_instance_v2.kube-master.0.access_ip_v4}"
    ]
  }
}

# install the dashboard and calico network

resource "null_resource" "overlay" {
  depends_on = ["null_resource.worker"]
  count = "${var.master_count}"
  connection {
    type = "ssh"
    user = "${var.ssh_user}"
    private_key = "${file(var.private_key_file)}"
    host = "${element(openstack_compute_instance_v2.kube-master.*.network.0.floating_ip, count.index)}"
  }

  # create a host file in this directory
  provisioner "local-exec" {
    command =  "./terraform.py --hostfile > hostfile"
  }

  # upload the host file to the node
  provisioner "file" {
    source = "hostfile"
    destination = "/home/${var.ssh_user}/hostfile"
  }
 
  # install the networking and dashboard 
  # append host file to /etc/hosts on the master. 
  # docs for calico: http://docs.projectcalico.org/v1.5/getting-started/kubernetes/installation/hosted/
  provisioner "remote-exec" {
    inline = [
      "sudo cat /etc/hosts hostfile >> /tmp/hosts",
      "sudo mv /tmp/hosts /etc/hosts",
      "kubectl apply -f https://git.io/weave-kube",
      #"sudo kubectl create -f http://docs.projectcalico.org/v1.5/getting-started/kubernetes/installation/hosted/kubeadm/calico.yaml",
      "sudo kubectl create -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml"
    ]
  } 

  # remove the local hostfile
  provisioner "local-exec" {
    command =  "rm hostfile"
  }
}
