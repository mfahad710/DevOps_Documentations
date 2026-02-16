# Ad Hoc Commands
Ad Hoc commands are the equivalent of "one-liners" They are quick, single-task commands that we run directly from our terminal without writing a full Playbook.

### Syntax
```bash
ansible [group_name] -m [module] -a "[arguments]"
```

To check all the modules in ansible
```bash
ansible-doc -l
```

### Ping Module Commands

To check which host in connected to the ansible, run
```bash
ansible all -m ping -u ansible
```
- `-m`: specify module 
- `ping`: module
- `-u`: specify remote user
- `ansible`: remote user

If check the hosts in different location, specific name for the remote inventory file is inventory

```bash
ansible all -i /home/inv -m ping
```
- `-i`: inventory
- `/home/inv`: inventory path

Check status of specific IP
```bash
ansible <ip-address> -m ping
```

Check status of two specific IP
```bash
ansible <ip-address>:<ip-address> -m ping
```

First edit the hosts file and create group of the hosts by
```bash
[fahad]
192.168.09.8
192.168.09.56
192.168.67.89
```

Then check
```bash
ansible <group-name> -m ping
ansible fahad -m ping
```

### Shell Module Commands

To check the memory of hosts
```bash
ansible all -m shell -a "free -h"
```

To check the IP of hosts
```bash
ansible all -m shell -a "ip r"
```

Check uptime of hosts that are in fahad group
```bash
ansible fahad -m shell -a "uptime"
```

- `-a`: give arguments to shell module

To create user in all servers
```bash
ansible all -m shell -a "useradd <username>" -b -K
```

- `-b`: become
- `-K`: Root privilege

To Check user created or not
```bash
ansible all -m shell -a "cat /etc/shadow | grep <username>" -b -K
ansible all -m shell -a "cat /etc/passwd | grep <username>" -b -K
```
 
### File Module Commands

To create dir directory in /home/fahad/dir and set permission
```bash
ansible all -m file -a "path=/home/fahad/dir state=directory mode=0777"
```

To delete dir directory in /home/fahad/dir
```bash
ansible all -m file -a "path=/home/fahad/dir state=absent"
```

To create dir.txt file in /home/fahad and set permission
```bash
ansible all -m file -a "path=/home/fahad/dir.txt state=touch mode=0777"
```

To delete dir.txt file in /home/fahad
```bash
ansible all -m file -a "path=/home/fahad/dir.txt state=absent"
```

### Copy Module Commands

To copy from ansible server to target
```bash
ansible all -m copy -a "src=/etc/ansible/facts.d/sshd.fact dest=/home/fahad/" -b -K
```

To run custom fact
```bash
ansible all -m setup -a "filter=ansible_local"
```

### apt Module Commands

To install package in all servers
```bash
ansible all -m apt -a "name=<package-name> state=present"
ansible all -m apt -a "name=tree state=present"
```

To delete package in all servers
```bash
ansible all -m apt -a "name=<package-name> state=absent" -b -K
```

To update package in all servers
```bash
ansible all -m apt -a "name=<package-name> state=latest" -b -K
```
