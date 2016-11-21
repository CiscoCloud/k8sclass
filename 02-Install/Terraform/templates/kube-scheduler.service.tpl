[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-scheduler --leader-elect=true --master=http://${hostip}:8080 --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
