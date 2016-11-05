#!/usr/bin/env python
# horribly written python code that grabs the servers and ports from openstack and
# generates the syntax of the command we need to run against them to make networking
# happen. 
import os
import re
import json

prefix = "vworker"
net_prefix = "10.201"


# get the metadata property worker_number.  This is actually set
# by terraform when we create the instance. 
# we want it to get the subnet overlay cbr0 interface ip address. 
def get_worker_number(server):
    # openstack server show vworker03 -c properties -f json
    
    p = os.popen('openstack server show ' + server + ' -f json -c properties')
    prop_raw = p.read()
    p.close()
    prop = json.loads(prop_raw)
    p_list = re.split(",", prop['properties'])
    for comp in p_list:
        #print "components: " + comp
        foo, bar = re.split("=", comp)
        #print "foo: " + foo
        if foo == " worker_number":
        # return the worker number
            #print "found worker number: " + bar
            return bar[1:-1]
    
# find the node based on the node prefix defined in the terraform file. 
print "Getting all the servers..."
p = os.popen('openstack server list -f json -c Name -c Networks --name ' + prefix + '.*',"r")
# read the output of the command. 
servers_raw = p.read()
#print servers_raw
p.close()
# the command gave us json, convert json into dictionary. 
servers = json.loads(servers_raw)
# make sure we have a list. 
if isinstance(servers, list):
    # go through each server:
    for server in servers:
        # the output is <subnet>=<ip>, e.g.: pipeline=10.106.0.123, split this up.
        server['subnet'], server['ip_address'] = re.split("=",  server['Networks'])

        # now we have to grab the worker number from it
        print "Getting information about " + server['Name']
        server['worker_number'] = get_worker_number(server['Name'])
        #print server['subnet']
        #print server['ip_address']
        

    # now get all the ports in the network.  Use the first server.  We assume they're all
    # in the same network so this should work. 
    print "Getting information about the ports..."
    p = os.popen('openstack port list -f json --network=' + servers[0]['subnet'])
    ports_raw = p.read()
    p.close()
    ports = json.loads(ports_raw)
    for port in ports:
        # this field looks like: "Fixed IP Addresses": "ip_address='10.106.1.188', subnet_id='e9e30169-44b0-4b17-8aaa-77852190875e'",
        # so we need to chop it up. 
        ip_list = re.split(",", port['Fixed IP Addresses'])
        for components in ip_list:
            foo, bar = re.split("=", components)
            # get rid of the quotes around the ip address and subnet id
            # 1 gets the opening ' and -1 gets the last '.
            port[foo] = bar[1:-1]
        #print port['ip_address']
        #print port['ID']
        for server in servers:
            if server['ip_address'] == port['ip_address']:
                server['port'] = port['ID']
                break
            
   
    # now we should have everything. 
    print "=" * 80
    print "Got all the information.  Please run the following commands to enable Kubernetes networking:\n\n"
    for server in servers:
        print "neutron port-update " + server['port'] + ' --allowed-address-pairs type=dict list=true ip_address=' + net_prefix + '.' + server['worker_number'] + '.0/24'
else:
    print "error getting openstack servers\n"

