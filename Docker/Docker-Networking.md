# Docker Networking

Docker networking is the system that enables containers to communicate with each other, the host, and external networks. It defines how data moves between containers and across systems during containerized application execution.  
It provides isolated, flexible network environments using built-in drivers like bridge, host, overlay, and none. Each driver supports different use cases, such as local development, swarm-based orchestration, or integration with legacy infrastructure.  

## Docker Network Commands

To check Docker networks list

```bash
docker network ls
```

Inspect Docker network

```bash
docker network inspect <Network_Name>
docker network inspect bridge
```

## Docker Network Types

Docker networks configure communications between neighboring containers and external services. Containers must be connected to a Docker network to receive network connectivity, and the communication routes available to the container depend on its network connections.

Docker supports six network types to manage container communication that implement core networking functionality:

### Bridge
Bridge networks create a software-based bridge between your host and the container  
The default for standalone containers. It creates a private internal network on the host, and containers can communicate through it using IPs or container names.  
Containers connected to the network can communicate with each other, but they’re isolated from those outside the network.

In default bridge network DNS is not supported but in user-defined bridge network DNS is supported.

![Bridge_Network]()

We can create our own bridge network through `docker network` command
```bash
docker network create --driver bridge my-bridge-net
```

we can also define the subnet and gateway in creatng network
```bash
docker network create --driver bridge my-bridge-net --subnet 10.0.0.0/16 --gateway 10.0.0.1
```

To Delete network
```bash
docker network rm my-bridge-net
```

To attach/connect the existing docker container with the newly created docker network then run

```bash
docker network connect <Bridge_Network_Name> <Container_Name/ID>
docker network connect my-bridge-net nginx-1
```

To deattach/disconnect the existing docker container with the newly created docker network then run

```bash
docker network disconnect <Bridge_Network_Name> <Container_Name/ID>
docker network disconnect my-bridge-net nginx-1
```

### Host
Removes network isolation by using the host’s network stack directly. This allows containers to share the host’s IP and ports, which is useful for performance or compatibility needs.  
Containers that use the host network mode share our host’s network stack without any isolation. They aren’t allocated their own IP addresses, and port binds will be published directly to our host’s network interface. This means a container process that listens on port 80 will bind to `<our_host_ip>:80`.

![Host_Network]()

### None
Disables networking completely. Useful for security or manual configuration.  
It disables all networking for a container. It prevents the container from being connected to any external network, including the default bridge network. This means the container cannot communicate with other containers or the host. It’s commonly used for containers that don’t need network access, such as isolated tasks or for enhanced security.

![None_Network]()

### Overlay
Enables multi-host networking using Docker Swarm. It creates a distributed network across nodes, allowing containers on different hosts to communicate securely.  
Overlay networks are distributed networks that span multiple Docker hosts. The network allows all the containers running on any of the hosts to communicate with each other without requiring OS-level routing support.  
Overlay networks implement the networking for Docker Swarm clusters, but you can also use them when you’re running two separate instances of Docker Engine with containers that must directly contact each other. This allows you to build your own Swarm-like environments.

![Overlay_Network]()


We need to create docker swarm init command first then create master and worker nodes cluster

```bash
docker swarm init
```

This generate `docker swarm join` command which we need to run in worker node so copy the command and paste it to the worker node 

```bash
docker swarm join --token <TOKEN> <IP>:<PORT>
```

Then create Overlay network between two nodes

In Master node create overlay network  
```bash
docker network create --driver overlay --attachable my-overlay-net
```

List the Network in master node  
```bash
docker network ls
```

Then run the container in master node that use this overlay network,  
> now in the worker node, if we check the `my-overlay-net` network, it is not present so in order to create the `my-overlay-net` overlay network we only need to run the contianer with the `my-overlay-net` network it automatically create the `my-overlay-net` network in the worker node.


### Macvlan
Assigns a MAC address to each container, making it appear as a physical device on the network. Used for scenarios requiring full network integration, such as legacy apps.  
macvlan is an advanced option that allows containers to appear as physical devices on our network. It works by assigning each container in the network a unique MAC address.  
This network type requires us to dedicate one of our host’s physical interfaces to the virtual network. The wider network must also be appropriately configured to support the potentially large number of MAC addresses that could be created by an active Docker host running many containers.  

![MACvLAN_Network]()


Create MACvLAN Network

```bash
docker network create --driver macvlan --subnet 192.165.50.0/24 --gateway 192.165.50.1 -o parent=ens33 my-macvlan-net
```

### IPvLAN
Similar to macvlan but uses a different method for traffic handling. It’s more efficient for high-density environments but less flexible.  
IPvLAN is an advanced driver that offers precise control over the IPv4 and IPv6 addresses assigned to your containers, as well as layer 2 and 3 VLAN tagging and routing.  
This driver is useful when you’re integrating containerized services with an existing physical network. IPvLAN networks are assigned their own interfaces, which offers performance benefits over bridge-based networking.  
IPvLAN also uses machine/host network. The port publish option is not present in this network

![IPvLAN_Network]()


Create IPvLAN Network

```bash
docker network create --driver ipvlan --subnet 192.165.50.0/24 --gateway 192.165.50.1 -o ipvlan_mode=12 -o parent=ens33 my-ipvlan-net 
```

