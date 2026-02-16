# Ansible Inventory

An Ansible inventory is a collection of managed hosts we want to manage with Ansible for various automation and configuration management tasks. Typically, when starting with Ansible, we define a static list of hosts known as the inventory. These hosts can be grouped into different categories, and then we can leverage various patterns to run our playbooks selectively against a subset of hosts. 

By default, the inventory is stored in `/etc/ansible/hosts`, but we can specify a different location with the `-i` flag or the `ansible.cfg` configuration file.

## Ansible inventory basics
The most common formats are either **INI** or **YAML**

### INI Format
```bash
[webservers]
host01.mycompany.com
host02.mycompany.com

[databases]
host03.mycompany.com
host04.mycompany.com
```

In this example, we use the INI format, define four managed hosts, and group them into two host groups: **webservers** and **databases**. The group names can be specified between brackets, as shown above.

Inventory Alias
```bash
db ansible_host=10.0.2.4
web ansible_host=10.0.2.5
```

#### Inventory Parameters
Behavioral Inventory Parameters (Connection Details):

- `ansible_host`: Specifies the hostname or IP address to connect to. Useful if the inventory entry is a logical name different from the actual connection address.
- `ansible_port`: The port number for the connection (e.g., SSH port). Default is 22 for SSH.
- `ansible_user`: The username to use for connecting to the managed node.
- `ansible_ssh_pass` or `ansible_password`: The password for SSH authentication.
- `ansible_ssh_private_key_file`: Path to the private key file for SSH authentication.
- `ansible_connection`: Specifies the connection type (e.g., ssh, local, winrm).
- `ansible_become`: Boolean (true/false) to enable privilege escalation (e.g., sudo).
- `ansible_become_user`: The user to become (e.g., root).
- `ansible_become_method`: The method for privilege escalation (e.g., sudo, su).
- `ansible_python_interpreter`: Path to the Python interpreter on the remote host.

#### Sample Inventory File
```bash
web       ansible_host=server1.company.com ansible_connection=ssh ansible_user=root
db        ansible_host=server2.company.com ansible_connection=winrm ansible_user=admin
mail      ansible_host=server3.company.com ansible_connection=ssh ansible_ssh_pass=P@#
web2      ansible_host=server4.company.com ansible_connection=winrm
localhost ansible_connection=localhost
```

### YAML Format
For more complex environments, the YAML format is highly recommended. Here’s an example of a YAML inventory designed for extensive and distributed systems

```bash
all:
  children:
    webservers:
      hosts:
        web1.example.com:
        web2.example.com:
    dbservers:
      hosts:
        db1.example.com:
        db2.example.com:
```


### Grouping and Parent Child Relationships
Ansible’s grouping functionality comes to the rescue when managing multiple servers simultaneously. We can define groups that represent collections of servers sharing similar roles. Once a group is defined, targeting that group for updates or configuration changes applies those changes to all associated servers.

- Define a parent group (**Web Servers**) to hold common configurations.
- Create child groups (**Web Servers US** and **Web Servers EU**) for location-specific settings.

**INI Format**  

```bash
[webservers:children]
webservers_us
webservers_eu

[webservers_us]
server1_us.com ansible_host=192.168.8.101
server2_us.com ansible_host=192.168.8.102

[webservers_eu]
server1_eu.com ansible_host=10.12.0.101
server2_eu.com ansible_host=10.12.0.102
```

**YAML Format**  

```bash
all:
  children:
    webservers:
      children:
        webservers_us:
          hosts:
            server1_us.com:
              ansible_host: 192.168.8.101
            server2_us.com:
              ansible_host: 192.168.8.102
        webservers_eu:
          hosts:
            server1_eu.com:
              ansible_host: 10.12.0.101
            server2_eu.com:
              ansible_host: 10.12.0.102
```
