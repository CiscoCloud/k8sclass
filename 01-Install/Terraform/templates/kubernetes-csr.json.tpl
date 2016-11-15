{
  \"CN\": \"kubernetes\",
  \"hosts\": [
    \"127.0.0.1\",
    \"kubernetes.default\",
    \"kubernetes.default.svc\",
    \"kubernetes.default.svc.cluster.local\",
    \"${cluster_ip}\",
    \"${public_ip}\",
    \"${lb_ip}\",
    ${worker_nodes},
    ${master_nodes}
  ],
  \"key\": {
    \"algo\": \"rsa\",
    \"size\": 2048
  },
  \"names\": [
    {
      \"C\": \"US\",
      \"L\": \"Portland\",
      \"O\": \"Kubernetes\",
      \"OU\": \"Cluster\",
      \"ST\": \"Oregon\"
    }
  ]
}
