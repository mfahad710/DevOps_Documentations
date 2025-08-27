---

# 🖥️ User Creation

This guide explains how to create a new user on a Linux VM, set up SSH access using public-private key pairs, and configure ssh-agent for easier authentication.

## Create a New User

### Add a new user

```bash
sudo adduser <username>
```
Prompts you to set a password and optional user details.

Switch to the new user

```bash
sudo su - <username>
```

### Set Up SSH Directory and Keys

Create `.ssh` directory and set permissions

```bash
mkdir ~/.ssh
chmod 700 ~/.ssh
```

`.ssh` directory stores SSH keys. **700** ensures only the user has access.

Add the user’s public key

```bash
echo "<public key of user>" >> ~/.ssh/authorized_keys
```

Change the permissions

```bash
chmod 600 ~/.ssh/authorized_keys
```

**authorized_keys** allows SSH access with the public key. **600** ensures only the user can read/write the file.

Exit back to the original user

```bash
exit
```

## Grant Sudo Privileges (Optional)

```bash
sudo usermod -aG sudo <username>
```

Adds the user to the sudo group for administrative commands.

## Create and Use ssh-agent

`ssh-agent` caches your SSH keys so you don’t need to enter passphrases repeatedly.

Start `ssh-agent`

```bash
eval $(ssh-agent)
```
Starts the agent.

Add your private key

```bash
ssh-add
```
Enter your key’s passphrase.

Create an alias for convenience

```bash
alias ssha='eval $(ssh-agent) && ssh-add'
```

Run `ssha` anytime to start the agent and add your key in one step.

## Copy Key to Server (Optional)

```bash
ssh-copy-id username@<IP>
```

Copies your public key to the remote server for passwordless login.

---