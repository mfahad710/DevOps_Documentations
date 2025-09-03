# User Setup Script (Ubuntu)

This script automates the process of setting up new users with **SSH access** and **sudo privileges** on a Linux server.  

## Features
- Updates and upgrades system packages.
- Creates new users with a default password.
- Adds users to the `sudo` group (granting administrative privileges).
- Configures secure SSH access with authorized keys.
- Ensures correct file and directory permissions for SSH authentication.

## How to run script

Create file (`user-setup.sh`)

```bash
touch user-setup.sh
```

Make the script executable

```bash
chmod +x user-setup.sh
```
Open the file in editor

```bash
vi user-setup.sh
```
Added the Script in the file

```bash
#!/bin/bash

# Update and upgrade system packages
sudo apt-get update
sudo apt-get upgrade -y

# Function to create a user with SSH key
create_user() {
    local username=$1
    local ssh_key=$2
    local password="fort@123"

    # Create the user and set their password
    sudo adduser --disabled-password --gecos "" $username
    echo "$username:$password" | sudo chpasswd

    # Add the user to the sudo group
    sudo usermod -aG sudo $username

    # Setup SSH directory and authorized_keys
    sudo mkdir -p /home/$username/.ssh
    sudo chmod 700 /home/$username/.ssh
    echo "$ssh_key" | sudo tee /home/$username/.ssh/authorized_keys
    sudo chmod 600 /home/$username/.ssh/authorized_keys
    sudo chown -R $username:$username /home/$username/.ssh
}

# Fort Admin user
create_user "fort-admin" "<FORT_ADMIN_PUBLIC_KEY>"

# Muhammad Azam user
create_user "fahad" "<FAHAD_PUBLIC_KEY>"

echo "Setup completed successfully!"
```

> **Replace `<FORT_ADMIN_PUBLIC_KEY>` and `<FAHAD_PUBLIC_KEY>` with the actual SSH public keys.**

## Script Overview

The script defines a function create_user that takes two arguments:

- **username** → the name of the user to be created.
- **ssh_key** → the public SSH key for the user.

The function:
- Creates the user without prompting for interactive details (`--disabled-password --gecos ""`).
- Sets a default password (`fort@123`).
- Adds the user to the `sudo` group.
- Configures the `.ssh` directory, sets correct permissions, and places the provided SSH public key in `authorized_keys`.

Finally, it calls this function twice to create two users:
- `fort-admin` with `<FORT_ADMIN_PUBLIC_KEY>`
- `fahad` with `<FAHAD_PUBLIC_KEY>`

**Run the script**

```bash
./user-setup.sh
```