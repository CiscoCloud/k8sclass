[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-apiserver --admission-control=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota --advertise-address=${hostip} --allow-privileged=true --apiserver-count=${count} --authorization-mode=ABAC --authorization-policy-file=/var/lib/kubernetes/authorization-policy.jsonl --bind-address=0.0.0.0 --enable-swagger-ui=true --etcd-cafile=/var/lib/kubernetes/ca.pem --insecure-bind-address=0.0.0.0 --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem --etcd-servers=${cluster} --service-account-key-file=/var/lib/kubernetes/kubernetes-key.pem --service-cluster-ip-range=${service_cluster_ip_range} --service-node-port-range=${service_port_range} --tls-cert-file=/var/lib/kubernetes/kubernetes.pem --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem --token-auth-file=/var/lib/kubernetes/token.csv -v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
