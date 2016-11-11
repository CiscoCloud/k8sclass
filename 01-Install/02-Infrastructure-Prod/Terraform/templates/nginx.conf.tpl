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
}
