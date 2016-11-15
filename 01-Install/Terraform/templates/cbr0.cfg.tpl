# Add the Container bridge network interface
auto cbr0
iface cbr0 inet static
     address ${docker_bridge}
pre-up brctl addbr cbr0

# add routes to our other kubernetes nodes. something like:  
# up route add -net 10.201.0.0/24 gw 10.106.1.144 dev ens3
# this makes our routes persistent. 
${static_routes}
