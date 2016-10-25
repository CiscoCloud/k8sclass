user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
        worker_connections 768;
        # multi_accept on;
}

stream {
        upstream kubernetes {
                server 10.106.1.2:6443;
                server 10.106.1.3:6443;
                server 10.106.1.5:6443;
        }

        server {
                listen 443;
                proxy_pass kubernetes;
        }
}
