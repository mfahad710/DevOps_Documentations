# Ansible Roles

Ansible roles provide a well-defined framework and structure for setting tasks, variables, handlers, metadata, templates, and other files. They enable us to reuse and share our Ansible code efficiently. This way, we can reference and call them in our playbooks with just a few lines of code while we can reuse the same roles over many projects without the need to duplicate our code.  

[Detail Explanation](https://spacelift.io/blog/ansible-roles)

### Ansible Galaxy
It is a free, public repository where the Ansible community shares Roles, Collections, and Playbooks. Instead of writing every single automation script from scratch (like "how to install a secured MySQL server"), you can go to Galaxy, find a battle-tested role created by an expert, and download it into your project

[Ansible Galaxy](https://galaxy.ansible.com/ui/)

### Where to store Local Roles

**Project-Specific Way**

Store roles inside a folder named `roles/` directly within Ansible project directory. This keeps automation portable.

**Global Way**

If we want roles to be available to every playbook on our Control Node, we can store them in the default system paths:

- Standard Path:   `~/.ansible/roles`
- System Path: `/usr/share/ansible/roles` or `/etc/ansible/roles`

### Commands

To Create Ansible Roles Directory 
```bash
ansible-galaxy init mysql
```

Find Roles
```bash
ansible-galaxy search mysql
```

Use Roles
```bash
ansible-galaxy  install <role_name>
```

Use in Current directory
```bash
ansible-galaxy install <role_name> -p ./roles
```

List Roles
```bash
ansible-galaxy list
```
OR
```bash
ansible-config dump | grep ROLE
```
