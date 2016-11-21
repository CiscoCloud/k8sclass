#!/bin/bash

## instructions from: http://kubernetes.io/docs/getting-started-guides/kubeadm/
sudo curl https://packages.cloud.google.com/apt/doc/apt-key.gpg > /tmp/apt-key.gpg
sudo apt-key add /tmp/apt-key.gpg
rm /tmp/apt-key.gpg
sudo cat <<EOF > /tmp/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo mv /tmp/kubernetes.list /etc/apt/sources.list.d/
sudo apt-get update
sudo apt-get install -y docker.io kubelet kubeadm kubectl kubernetes-cni
