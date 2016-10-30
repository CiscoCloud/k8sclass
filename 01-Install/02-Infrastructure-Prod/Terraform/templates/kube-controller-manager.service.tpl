[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-controller-manager --allocate-node-cidrs=true --cluster-cidr=${cluster_cidr} --cluster-name=${cluster_name} --leader-elect=true --master=http://${hostip}:8080 --root-ca-file=/var/lib/kubernetes/ca.pem --service-account-private-key-file=/var/lib/kubernetes/kubernetes-key.pem --service-cluster-ip-range=${service_cluster_ip_range} --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
