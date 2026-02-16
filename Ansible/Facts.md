# Ansible Facts

Ansible connects to each target machine and automatically gathers essential details such as:

- Architecture (e.g., 32-bit vs 64-bit)
- Operating system version
- Processor and memory specifications
- Network interfaces, IP addresses, FQDN, and MAC addresses
- Disk details

This comprehensive data collection is managed by the **setup** module, which is executed automatically at the beginning of every playbook unless **explicitly** disabled.

### Simple Playbook Example
Consider the following playbook that prints a simple hello message. Even though only the debug task is specified in the playbook, Ansible first gathers facts from each host:

```bash
- name: Print hello message
  hosts: all
  tasks:
    - debug:
        msg: Hello from Ansible!
```

When we run this playbook, the output includes two key tasks: one that gathers facts and another that prints the debug message.

```bash
PLAY [Print hello message] *******************************

TASK [Gathering Facts] ***********************************
ok: [web2]
ok: [web1]

TASK [debug] *********************************************
ok: [web1] => {
    "msg": "Hello from Ansible!"
}
ok: [web2] => {
    "msg": "Hello from Ansible!"
}
```
​
### Displaying Ansible Facts
To gain deeper insights, we can modify our playbook to print the `ansible_facts` variable instead of a simple message. This approach allows us to view extensive system details for each host:

```bash
- name: Print Ansible Facts
  hosts: all
  tasks:
    - debug:
        var: ansible_facts
```

Running this playbook produces output similar to the example below, featuring details such as IP configurations, system architecture, operating system information, DNS settings, and memory statistics:

```bash
PLAY [Reset nodes to previous state] *********************************************************************** 

TASK [Gathering Facts] ***************************************************************************************
ok: [web2]
ok: [web1]

TASK [debug] ************************************************************************************************
ok: [web1] =>
  "ansible_facts": {
    "all_ipv4_addresses": [
      "172.20.1.100"
    ],
    "architecture": "x86_64",
    "date_time": {
      "date": "2019-09-07",
    },
    "distribution": "Ubuntu",
    "distribution_file_variety": "Debian",
    "distribution_major_version": "16",
    "distribution_release": "xenial",
    "distribution_version": "16.04",
    "dns": {
      "nameservers": [
        "127.0.0.11"
      ]
    },
    "fqdn": "web1",
    "hostname": "web1",
    "interfaces": [
      "lo",
      "eth0"
    ],
    "machine": "x86_64",
    "memfree_mb": 72,
    "memory_mb": {
      "real": {
        "free": 72,
        "total": 985,
        "used": 913
      }
    }
  },
```

The rich details provided by `ansible_facts` can be invaluable when configuring systems dynamically—whether we are setting up logical volumes, managing network settings, or optimizing system performance based on the hardware characteristics of our servers.
​
### Disabling Fact Gathering
If our playbook does not require this additional overhead of gathering facts, you can disable it by setting the `gather_facts` option to `no`

```bash
- name: Print hello message without gathering facts
  hosts: all
  gather_facts: no
  tasks:
    - debug:
        var: ansible_facts
```

With `gather_facts: no`, Ansible skips the facts collection phase and executes only the specified tasks. Note that fact-gathering behavior can be further controlled by the setting in the Ansible configuration file (typically located at `/etc/ansible/ansible.cfg`):

```bash
# /etc/ansible/ansible.cfg
# By default, plays will gather facts automatically. The settings include:
# smart     - Gather by default, but do not regather if already gathered
# implicit  - Gather by default, turn off with gather_facts: False
# explicit  - Do not gather by default; must enable with gather_facts: True
gathering = implicit
```

If both the playbook and configuration file specify fact-gathering options, the playbook setting takes precedence.
​
### Targeted Fact Gathering
Remember that Ansible collects facts only for the hosts included in the playbook. For example, if our inventory has two hosts (**web1 and web2**) but we run the playbook only on web1, facts will be gathered solely for **web1**:

```bash
- name: Print Ansible Facts for web1 only
  hosts: web1
  tasks:
    - debug:
        var: ansible_facts
```

This behavior might result in missing facts for hosts not targeted by the playbook.
