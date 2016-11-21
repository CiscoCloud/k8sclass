[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-proxy --master=${master} --kubeconfig=/var/lib/kubelet/kubeconfig --proxy-mode=iptables --v=4 
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
