# Add the Container bridge network interface
auto cbr0
iface cbr0 inet static
     address ${docker_bridge}
pre-up brctl addbr cbr0
