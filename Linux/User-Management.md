# User Management Guide

## Introduction

User management in Linux is the process of creating, modifying, deleting, and managing user accounts and groups. It is a fundamental administrative task for system administrators and DevOps engineers.


## Types of Accounts

### Root User

-   UID: 0
-   Has full administrative privileges.
-   Can modify any file and execute any command.

### System Accounts

-   Used by services and system processes.
-   Typically have UID range: 1 - 999 (distribution dependent).
-   Examples: **www-data**, **bind**, **mysql**, **nginx**.
-   Usually cannot log in interactively.

### Regular (Human) Users

-   Created for actual users.
-   Default UID range: 1000 - 60000 (depends on distro).
-   Can log in and perform tasks based on assigned permissions.


## Important System Files

- `/etc/passwd`  
    - Stores basic user account information.
    - **Format**: `username:x:UID:GID:comment:home_directory:login_shell`
    - **Example**: `fahad:x:1001:1001:Fahad:/home/fahad:/bin/bash`

- `/etc/shadow`  

    - Stores encrypted passwords and password aging information. Only readable by root.

- `/etc/group`  
    - Stores group information.
    - **Format**: `groupname:x:GID:user1,user2`

- `/etc/login.defs`  

    - Defines UID/GID ranges and password policy defaults.

- `/etc/skel`

    - Contains default files copied to a new user's home directory.


## User Management Commands

### Add User

High-level command (recommended on Ubuntu/Debian): `sudo adduser username`

Low-level command: `sudo useradd -m username`

### Delete User

`sudo userdel username`  
`sudo userdel -r username` // Remove home directory

### Modify User

`sudo usermod options username`

**Examples**:
- Add user to group: `sudo usermod -aG groupname username`
- Change primary group: `sudo usermod -g groupname username`
- Change login shell: `sudo usermod -s /bin/bash username`

### Lock / Unlock User

- Lock User: `sudo passwd -L username`  
- Unlock User: `sudo passwd -u username`

### Force Password Change

`sudo passwd -e username`

## Password Expiry Policies

- Set maximum password age: `sudo passwd -x 30 username`
- Set warning days: `sudo passwd -w 7 username`


## Group Management

### Create Group

`sudo groupadd groupname`  
`sudo groupadd -g 1050 groupname` // Specific GID

### Delete Group

`sudo groupdel groupname`

### Remove User from Group

`sudo gpasswd -d username groupname`

## Switching Users

- Switch to root: `sudo -i` , `sudo su -`
- Switch to another user:  `su - username`


## Useful User Information Commands

Check user details: `id username`


## File Ownership & Permissions

### Change Ownership

`sudo chown user:group file`

### Change Permissions

`chmod 755 file`  

Permission categories: - User (owner) - Group - Others

## Sudoers File Management

### What is sudo?

sudo allows permitted users to execute commands as root or another user.

### Sudo Configuration File

Main file: `/etc/sudoers`  

Never edit directly using a normal editor. Use: `sudo visudo`

### Basic Sudoers Syntax

`username ALL=(ALL) ALL`  

- Meaning: username host=(run_as_user) command
- Example: `fahad ALL=(ALL) ALL`

Allow user to run specific command only: `fahad ALL=(ALL) /usr/bin/systemctl`

### Add User to Sudo Group (Ubuntu/Debian)

`sudo usermod -aG sudo username`  

### Sudo Group File

Group sudo is defined in: `/etc/group`

### Disable Root Login (Best Practice)

Instead of logging in as root, grant sudo privileges to trusted users.
