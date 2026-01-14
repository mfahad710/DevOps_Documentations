# 🔐 Polkit (PolicyKit) Configuration & Setup Guide
_For RHEL 7.9 / CentOS 7_

## Overview

**Polkit (PolicyKit)** is a Linux authorization framework that controls **which users can perform privileged system actions** — such as restarting services, mounting disks, or modifying system settings — without requiring full root privileges.

## Why It’s Needed

When a non-root user runs:
```bash
systemctl restart <Service_Name>
```
it communicates with **systemd** through **D-Bus**, which is protected by **Polkit**.

By default, Polkit denies this request and asks for authentication:
```
Authentication is required to manage system services or units.
Choose identity to authenticate as (1-14):
```

To enable non-interactive deployments, we must configure Polkit to trust the user for this action.

## Step 1 – Check if Polkit Is Installed

```bash
rpm -qa | grep polkit
```

Expected packages:
```
polkit-0.112-26.el7.x86_64
polkit-pkla-compat-0.1-4.el7.x86_64
```

If not installed:
```bash
sudo yum install polkit polkit-pkla-compat -y
```

Verify the service:
```bash
systemctl status polkit
```

Should show **Active (running)**.

## Step 2 – Understand Polkit Components

| Component | Purpose |
|------------|----------|
| `polkitd` | The main daemon (authorization manager). |
| `.pkla` files | Legacy rules for RHEL 7 / CentOS 7. |
| `.rules` files | JavaScript-style rules (used on RHEL 8+). |
| `polkit-pkla-compat` | Compatibility layer that enables `.pkla` files on RHEL 7. |
| `/usr/share/polkit-1/actions/` | Lists all available actions Polkit can authorize (XML descriptors). |

---

## Step 3 – Create a Rule for GitLab Deploy User

#### For RHEL 7.x

use the `.pkla` format.

Create file:
```
/etc/polkit-1/localauthority/50-local.d/ps-gitlab-systemctl.pkla
```

Add:
```ini
[Allow ps-gitlab to manage systemd services]
Identity=unix-user:ps-gitlab
Action=org.freedesktop.systemd1.manage-units
ResultAny=yes
ResultInactive=yes
ResultActive=yes
```

Set permissions:
```bash
sudo chown root:root /etc/polkit-1/localauthority/50-local.d/ps-gitlab-systemctl.pkla
sudo chmod 644 /etc/polkit-1/localauthority/50-local.d/ps-gitlab-systemctl.pkla
```

Restart Polkit:
```bash
sudo systemctl restart polkit
```


#### For RHEL 8 
use the `.rules` format

Create file:
```
cd /etc/polkit-1/rules.d
touch 50-ps-gitlab-systemctl.rules
```

Add the following rule in file
```bash
// Allow ps-gitlab to manage systemd units without password
const allowed_users = ["ps-gitlab"];

polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units") {
        if (allowed_users.indexOf(subject.user) >= 0) {
            return polkit.Result.YES;
        }
    }
});
```

Set Permissions
```bash
sudo chown root:root /etc/polkit-1/rules.d/50-ps-gitlab-systemctl.rules
sudo chmod 644 /etc/polkit-1/rules.d/50-ps-gitlab-systemctl.rules
```

Restart Polkit:
```bash
sudo systemctl restart polkit
```


## Step 4 – Test the Rule

Switch to your deploy user:
```bash
sudo su - ps-gitlab
systemctl restart <Service_Name>
```

Expected result: Service restarts **without authentication prompt**.

##Step 5 – Verify Configuration

Check that Polkit service is active:
```bash
systemctl status polkit
```

List Polkit actions:
```bash
pkaction | grep systemd1.manage-units
```

Verify `.pkla` file exists and has correct permissions:
```bash
ls -l /etc/polkit-1/localauthority/50-local.d/ps-gitlab-systemctl.pkla
```

---

## Optional – Sudoers Configuration

For CI/CD environments, it’s also common to grant passwordless sudo:

Edit via:
```bash
sudo visudo
```

Add lines:
```
Defaults:ps-gitlab !requiretty
ps-gitlab ALL=(ALL) NOPASSWD: ALL
```

This ensures `sudo systemctl restart ...` also works non-interactively.

## Architecture Diagram

```
┌────────────────────────────┐
│  GitLab Runner (Docker)   │
│  runs deploy job          │
└─────────────┬──────────────┘
              │ SSH key (key.pem)
              ▼
      ┌───────────────────────┐
      │  UAT Server           │
      │  User: ps-gitlab      │
      └──────────┬────────────┘
                 │
                 ▼
        ┌────────────────────┐
        │ systemctl (client) │
        └──────────┬─────────┘
                   │ D-Bus call
                   ▼
        ┌────────────────────┐
        │   polkitd daemon   │
        │  (authorization)   │
        └──────────┬─────────┘
                   │ Authorized
                   ▼
        ┌────────────────────┐
        │   systemd (root)   │
        │ Restarts service   │
        └────────────────────┘
```

## Commands Reference

| Action | Command |
|---------|----------|
| Check version | `pkaction --version` |
| Restart Polkit | `systemctl restart polkit` |
| View logs | `journalctl -u polkit -n 20` |
| Verify rule active | `systemctl restart <service>` as deploy user |

## Summary

| Goal | Command/Config | Result |
|------|----------------|--------|
| Install Polkit | `yum install polkit polkit-pkla-compat -y` | Installed |
| Enable service | `systemctl enable --now polkit` | Running |
| Add rule | `.pkla` file in `/etc/polkit-1/localauthority/50-local.d/` | Deploy user authorized |
| Restart service (test) | `systemctl restart <Service_Name>` | Works silently |
| Integration with GitLab | Deploy step restarts service automatically | ✅ Success |
