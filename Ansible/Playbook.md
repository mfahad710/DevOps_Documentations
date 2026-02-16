# Ansible Playbook

Ansible Playbooks offer a repeatable, reusable, simple configuration management and multi-machine deployment system, one that is well suited to deploying complex applications. If we need to execute a task with Ansible more than once, write a playbook and put it under source control. Then we can use the playbook to push out new configuration or confirm the configuration of remote systems.

![Playbook-Example](../Images/Ansible/Playbook-Example.png)

![Playbook_Hierarchy](../Images/Ansible/Playbook-Hierarchy.png)

To run Ansible playbook
```bash
ansible-playbook <playbook-filename>
ansible-playbook playbook.yml
```
