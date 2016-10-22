[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-proxy --master=https://10.240.0.10:6443 --kubeconfig=/var/lib/kubelet/kubeconfig --proxy-mode=iptables --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
