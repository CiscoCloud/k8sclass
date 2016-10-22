[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/kubelet --allow-privileged=true --api-servers=${api_servers} --cloud-provider= --cluster-dns=${cluster_dns} --cluster-domain=cluster.local --configure-cbr0=true --container-runtime=docker --docker=unix:///var/run/docker.sock --network-plugin=kubenet --kubeconfig=/var/lib/kubelet/kubeconfig --reconcile-cidr=true --serialize-image-pulls=false --tls-cert-file=/var/lib/kubernetes/kubernetes.pem --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
