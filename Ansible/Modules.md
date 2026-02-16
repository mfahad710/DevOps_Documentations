# Ansible Modules

Module is a small program that performs actions on a local machine, application programming interface (API), or remote host. Modules are expressed as code, usually in Python, and contain metadata that defines when and where a specific automation task is executed and which users can execute it.

Modules are grouped as follows:

- `System Modules`: Perform actions at the operating system level, such as managing users and groups, configuring IP tables and firewalls, handling logical volumes, managing mount operations, and controlling services (start, stop, restart)
    - User
    - Groups
    - Hostname
    - Iptables
    - Mount
    - Ping
    - Systemd
    - Service

- `Command Modules`: Allow execution of commands or scripts on a host. Use the command module for simple commands or the expect module for interactive commands.
    - Commands
    - Expect
    - Raw
    - Script
    - Shell

- `File Modules`: Facilitate operations on files, including setting file permissions with ACL, compression with archive/unarchive, and file content modifications using modules like **ACL**, **Archive**, **Copy**, **File**, **Find**, **Lineinfile**, **Replace**, **Stat**, **Template** **Unarchive**.  

- `Database Modules`: Manage database operations for systems such as **MongoDB**, **MySQL**, **MS SQL**, and **PostgreSQL**, allowing us to add, remove, or update configurations.  

- `Cloud Modules`: Offer robust functionalities for various cloud providers including **AWS**, **Azure**, **Docker**, **Google Cloud**, **OpenStack**, and **VMware**.  

- `Windows Modules`: Optimize management of Windows environments. Modules like **win_copy**, **win_command**, **win_service**, and others help with tasks ranging from file transfer to installing software and managing Windows services.
