# Introduction Installation and Configuration

## Introduction:
Ansible is an open-source automation tool that simplifies and automates various manual processes, including provisioning, configuration management, application deployment, and orchestration.  

It is created by contributions from an active open-source community. Ansible is designed to be simple, powerful, and agentless, which means it does not require any software or agents to be installed on the managed nodes.  

### Core Components

#### Control Node:
The Control Node is the "brain" of the operation. It is the machine where Ansible is actually installed. From here, we run commands and "playbooks" (our automation scripts) to manage our infrastructure.

#### Managed Nodes:
Managed Nodes (sometimes called "hosts") are the remote systems, servers, or devices that we are managing with Ansible.

## Installation:

#### Control node requirements:
We can use nearly any UNIX-like machine with **Python** installed. This includes Red Hat, Debian, Ubuntu, macOS, BSDs, and Windows under a Windows Subsystem for Linux (WSL) distribution. Windows without WSL is not natively supported as a control node.  

#### Managed node requirements:
The managed node does not require Ansible to be installed, but requires Python to run Ansible-generated Python code. The managed node also needs a user account that can connect through SSH to the node with an interactive POSIX shell.  

> **Link:** [Installation Guide](https://docs.ansible.com/projects/ansible/latest/installation_guide/index.html)
>> **Note:** The Installation procedure is changed over time, so the best way to install Ansible is to follow the official documentation of Ansible.

## Configuration:

### Controller Node
After Installing Ansible, create an Ansible user.
```bash
sudo useradd -m ansible
```

Create user password
```bash
sudo passwd ansible
```

Add ansible user in sudo group 
```bash
sudo usermod -aG sudo ansible
```

Now we need to add sudo entry for ansible user
Login as root user
```bash
sudo -i
```

Open visudo file in any editor
```bash
visudo /etc/sudoers
```

Edit the file by adding the below line in  #User priviliege specification section
```bash
#User priviliege specification
ansible ALL=(ALL) NOPASSWD:ALL
```

Edit the ssh configuration file
```bash
vim /etc/ssh/sshd_config
```

Edit the file by adding the below line, sometimes it comments so uncomment it.

```bash
Match User ansible
    PasswordAuthentication no
    PubkeyAuthentication yes
```

Restart ssh service
```bash
sudo service sshd restart
```

Now generate SSH key in master
```bash
ssh-keygen -b 2048 -t rsa
```

Add ansible server’s public key in node server which we want to connect with ansible server
By,
 
Copy the public key (**id_rsa.pub**) and paste it in the node server’s ssh directory
```bash
/.ssh/authorized_keys
```

OR
```bash
ssh-copy-id ansible@<node-IP-address>
```

After copying, we need to check and login ssh via remote from master to worker
```bash
ssh ansible@<node-IP-address>
```

#### Configuration File

Create or edit the default config file:
```bash
sudo mkdir -p /etc/ansible
sudo nano /etc/ansible/ansible.cfg
```

Paste this starter config:
```bash
[defaults]
inventory = /etc/ansible/hosts
remote_user = ansible
private_key_file = ~/.ssh/id_rsa
```

We can generate an Ansible configuration file, **ansible.cfg**, that lists all default settings as follows:
```bash
ansible-config init --disabled > ansible.cfg
```

Include available plugins to create a more complete Ansible configuration as follows:
```bash
ansible-config init --disabled -t all > ansible.cfg
```

To see all available configuration options and their corresponding environment variables, use the `ansible-config` command:

List all configuration options with their default values:
```bash
ansible-config list  # Lists all configurations
```

View the currently active configuration file:
```bash
ansible-config view  # Displays the current configuration file
```

Dump the full configuration (with sources):
```bash
ansible-config dump  # Shows current settings and their origins
```

Consider the following example that sets fact gathering to explicit and verifies the change:
```bash
export ANSIBLE_GATHERING=explicit
ansible-config dump | grep GATHERING
DEFAULT_GATHERING: explicit
```

This confirms that Ansible has overridden the configuration using the environment variable. Such commands are invaluable when troubleshooting configuration issues.

#### Inventory File

Then create the inventory file if it doesn’t exist:
```bash
sudo nano /etc/ansible/hosts
```

Example inventory:
```bash
[webservers]
host1 ansible_host=<IP>
host2 ansible_host=<IP>
host3 ansible_host=<IP>
```

### Managed Node
Create Ansible user in every server for which we have to operate through ansible  
Server required **python** installed

create an Ansible user
```bash
sudo useradd -m ansible
```

Create user password
```bash
sudo passwd ansible
```

Add ansible user in sudo group
```bash
sudo usermod -aG sudo ansible
```

Now we need to add sudo entry for ansible user
Login as root user
```bash
sudo -i
```

Open visudo file in any editor
```bash
visudo /etc/sudoers
```

Edit the file by adding the below line
```bash
#User priviliege specification
ansible ALL=(ALL) NOPASSWD:ALL
```

Edit the ssh configuration file
```bash
vim /etc/ssh/sshd_config
```

Edit the file by adding the below line, sometimes it comments so uncomment it.
```bash
Match User ansible
    PasswordAuthentication no
    PubkeyAuthentication yes
```

Restart ssh service
```bash
sudo service sshd restart
```
