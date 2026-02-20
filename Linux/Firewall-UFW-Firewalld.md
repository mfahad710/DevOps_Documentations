# Firewall Management (UFW & Firewalld)

## UFW (Uncomplicated Firewall)

UFW (Uncomplicated Firewall) is a frontend tool for managing iptables firewall rules. It is commonly used in Debian-based distributions like Ubuntu and Debian.

**Important Configuration Files**

-   /etc/default/ufw
-   /etc/ufw/ufw.conf
-   /etc/ufw/before.rules
-   /etc/ufw/after.rules

**Installation**

``` bash
sudo apt update
sudo apt install ufw
```

Check version:

``` bash
ufw version
```

**Default Policies**

``` bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

**Enable / Disable**

``` bash
sudo ufw enable
sudo ufw disable
sudo ufw reset
```

**Status Commands**

``` bash
sudo ufw status
sudo ufw status verbose
sudo ufw status numbered
```

**Application Profiles**

``` bash
sudo ufw app list
sudo ufw app info OpenSSH
```

Profiles directory: `/etc/ufw/applications.d/`

**Allow Rules**

By application:

``` bash
sudo ufw allow OpenSSH
```

By service:

``` bash
sudo ufw allow ssh
sudo ufw allow http
```

By port:

``` bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443/tcp
```

Port range:

``` bash
sudo ufw allow 3000:3010/tcp
sudo ufw allow 4000:4010/udp
```

Allow specific IP:

``` bash
sudo ufw allow from 192.168.1.10
sudo ufw allow from 192.168.1.10 to any port 22
```

**Deny Rules**

``` bash
sudo ufw deny http
sudo ufw deny from 192.168.1.10
sudo ufw deny 23
```

**Delete Rules**

``` bash
sudo ufw delete allow 80
sudo ufw delete allow ssh
sudo ufw delete <rule-number>
```

**Reload**

``` bash
sudo ufw reload
```

### Logging

``` bash
sudo ufw logging on
sudo ufw logging medium
```

Log file: `/var/log/ufw.log`

## Firewalld

Firewalld is a dynamic firewall management tool mainly used in RHEL-based systems like Red Hat, CentOS, and Rocky Linux. It uses zones for managing network trust levels.

**Installation**

``` bash
sudo dnf install firewalld
```

or

``` bash
sudo yum install firewalld
```

**Start & Enable**

``` bash
sudo systemctl start firewalld
sudo systemctl enable firewalld
sudo systemctl status firewalld
```

Check state:

``` bash
sudo firewall-cmd --state
```

### Zones

List zones:

``` bash
sudo firewall-cmd --get-zones
```

Active zones:

``` bash
sudo firewall-cmd --get-active-zones
```

Common zones:
- public
- internal
- dmz
- trusted
- block

### Allow Services

Temporary:

``` bash
sudo firewall-cmd --add-service=http
```

Permanent:

``` bash
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --reload
```

Allow SSH:

``` bash
sudo firewall-cmd --add-service=ssh --permanent
sudo firewall-cmd --reload
```

**Allow Ports**

Temporary:

``` bash
sudo firewall-cmd --add-port=8080/tcp
```

Permanent:

``` bash
sudo firewall-cmd --add-port=8080/tcp --permanent
sudo firewall-cmd --reload
```

### Remove Rules

Remove service:

``` bash
sudo firewall-cmd --remove-service=http --permanent
```

Remove port:

``` bash
sudo firewall-cmd --remove-port=8080/tcp --permanent
```

Reload:

``` bash
sudo firewall-cmd --reload
```

### List Rules

``` bash
sudo firewall-cmd --list-services
sudo firewall-cmd --list-ports
sudo firewall-cmd --list-all
```

### Rich Rules

Allow specific IP:

``` bash
sudo firewall-cmd --add-rich-rule='rule family="ipv4" source address="192.168.1.10" accept' --permanent
```

Allow IP to specific port:

``` bash
sudo firewall-cmd --add-rich-rule='rule family="ipv4" source address="192.168.1.10" port port="22" protocol="tcp" accept' --permanent
```

### Runtime vs Permanent

-   Runtime: Temporary (lost after reboot)
-   Permanent: Saved after reboot

Convert runtime to permanent:

``` bash
sudo firewall-cmd --runtime-to-permanent
```

## UFW vs Firewalld Comparison

| Feature | UFW | Firewalld |
|---|---|---|
| Used in | Debian-based | RHEL-based |
| Complexity | Simple | Advanced |
| Zones | No | Yes |
| Best For | Small servers | Enterprise systems |

