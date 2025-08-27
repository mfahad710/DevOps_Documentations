# 📘 Linux Alias – Guide

Aliases are shortcuts for commands that facilitate more productive work on the terminal. This guide shows how to set up aliases in Linux.

## What is an Alias?

Aliases allow you to create custom shortcuts for frequently used commands. Instead of typing long commands repeatedly, we can create a short alias to execute them.

For Example:

```bash
alias lah='ls -lah --color=auto'
```

Now typing `lah` will execute `ls -lah --color=auto`.

## Types of Aliases

**1. Temporary Alias:**

A temporary alias exists only for the current shell session. It will be lost after we close the terminal.

**2. Permanent Alias:**

A permanent alias is stored in a shell configuration file so it loads every time you open a terminal.

- Add aliases inside `~/.bashrc` (for Bash users)
- Or inside `~/.zshrc` (for Zsh users)

## Setting Up Alias

### Temporary Alias

Create a **Temporary** alias:

```bash
alias name='command'
```

Example:

```bash
alias gs='git status'
```

Remove a temporary alias:
```bash
unalias gs
```

### Permanent Alias

### 1. Edit the .bashrc File

Open the `.bashrc` file in your home directory using a text editor:

```bash
sudo nano ~/.bashrc
```

**Note**: The `.bashrc` file is executed every time you start a new bash session, making aliases persistent across sessions.

### 2. Add Your Alias

Add your alias at the end of the `.bashrc` file. Here's an example for setting up a server connection:

```bash
# Custom aliases
alias servssh="ssh muhammadfahad@52.186.183.86"
```

**Syntax**: `alias alias_name="command_to_execute"`

### 3. Reload the Configuration

After adding the alias, reload the terminal configuration to apply changes:

```bash
source ~/.bashrc
```

**Alternative**: You can also restart your terminal or open a new terminal session.

### 4. Use Your Alias

Now you can use your alias in the terminal:

```bash
servssh
```

This will execute: `ssh muhammadfahad@52.186.183.86`

## Managing Aliases

### View All Aliases

To see all currently defined aliases:

```bash
alias -p
```

### Remove an Alias

To temporarily remove an alias from the current session:

```bash
unalias servssh
```

**Note**: This only removes the alias from the current session. It will be restored when you start a new session.

## System-wide Aliases (For All Users)

If we want aliases to be available for all users, we can set them inside `/etc/profile.d/`.

- Step 1: Create the aliases file
```bash
sudo nano /etc/profile.d/aliases.sh
```

- Step 2: Add aliases
```bash
alias ll='ls -lah --color=auto'
alias gs='git status'
alias grep='grep --color=auto'
```

- Step 3: Make it executable
```bash
sudo chmod +x /etc/profile.d/aliases.sh
```

- Step 4: Apply changes immediately
```bash
source /etc/profile.d/aliases.sh
```

Now our aliases will work for all users automatically at login.


### **This setup works with both Debian-based systems (Ubuntu, Linux Mint) and RPM-based systems (RHEL, CentOS, Fedora)**

## Best Practices

1. **Use descriptive names**: Make alias names intuitive and easy to remember
2. **Group related aliases**: Add comments to organize your aliases
3. **Backup your .bashrc**: Keep a backup of your configuration file

---

*This documentation covers the essential steps for setting up and managing aliases in Linux systems.*
