# Ansible Playbook

Ansible Playbooks offer a repeatable, reusable, simple configuration management and multi-machine deployment system, one that is well suited to deploying complex applications. If we need to execute a task with Ansible more than once, write a playbook and put it under source control. Then we can use the playbook to push out new configuration or confirm the configuration of remote systems.

![Playbook_Example](../Images/Ansible/Playbook_Example.png)

### Components
An Ansible playbook is a YAML file that contains a list of **plays**. Each play targets specific **hosts** defined in our inventory and comprises multiple **tasks**. A task represents a single **action**, such as executing a command, running a script, installing a package, or restarting a service.

![Playbook_Hierarchy](../Images/Ansible/Playbook_Hierarchy.png)


### Sample Playbook
```bash
- name: Configure Apache Web Servers
  hosts: localhost
  tasks:
    - name: Execute command 'date'
      command: date

    - name: Execute script on server
      script: test_script.sh

    - name: Install httpd service
      yum:
        name: httpd
        state: present

    - name: Start web server
      service:
        name: httpd
        state: started
```

### Multiple Plays in a Single Playbook
```bash
- name: Play 1
  hosts: localhost
  tasks:
    - name: Execute command 'date'
      command: date

    - name: Execute script on server
      script: test_script.sh

- name: Play 2
  hosts: localhost
  tasks:
    - name: Install web service
      yum:
        name: httpd
        state: present

    - name: Start web server
      service:
        name: httpd
        state: started
```

To run Ansible playbook
```bash
ansible-playbook <playbook-filename>
ansible-playbook playbook.yml
```
