user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
        worker_connections 768;
        # multi_accept on;
}

stream {
        upstream kubernetes {
                server ${server1}:6443;
                server ${server2}:6443;
                server ${server3}:6443;
        }

        server {
                listen 443;
                proxy_pass kubernetes;
        }
}

http {
        # kubernetes dashboard
        upstream workers {
                server ${worker1}:9999;
                server ${worker2}:9999;
        }


        server {
                listen 80;
                server_name _;
                auth_basic "auth required";
                auth_basic_user_file /etc/nginx/htpasswd;

                location / {
                        proxy_pass http://workers;
                }
        }

        # grafana service
        upstream graphana {
                server ${worker1}:30861;
                server ${worker2}:30861;
        }


        server {
                listen 3000;
                server_name _;
                auth_basic "auth required";
                auth_basic_user_file /etc/nginx/htpasswd;

                location / {
                        proxy_pass http://graphana;
                }
        }

        # kibana service
        upstream kibana {
                server ${worker1}:31709;
                server ${worker2}:31709;
        }


        server {
                listen 5601;
                server_name _;
                auth_basic "auth required";
                auth_basic_user_file /etc/nginx/htpasswd;

                location / {
                        proxy_pass http://kibana;
                }
        }
        # guestbook service
        upstream guestbook {
                server ${worker1}:31433;
                server ${worker2}:31433;
        }


        server {
                listen 8888;
                server_name _;
                location / {
                        proxy_pass http://guestbook;
                }
        }
}
