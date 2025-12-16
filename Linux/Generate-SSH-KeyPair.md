# 🔑 Generating SSH Key Pairs

## Introduction

In cryptography, a key pair consists of

- **Private key** → kept secret, used for authentication/signing.
- **Public key** → shared openly, used for verification/encryption.

SSH (**Secure Shell**) commonly uses public-key cryptography for secure access to servers. Two popular algorithms are

- 🔒 **RSA (Rivest–Shamir–Adleman)**

RSA is a widely used algorithm based on **prime factorization**. Keys range from **2048** to **4096** bits, with larger sizes offering stronger security. It is slower in signing and verification but highly compatible across all systems, making it useful where legacy support is needed.

- 🔒 **Ed25519 (Edwards-curve Digital Signature Algorithm 25519)**

Ed25519 is a modern **elliptic curve** algorithm with a fixed **256-bit** key size. It is faster, more efficient, and provides around **128-bit** security. Supported in **OpenSSH 6.5** and later, it is recommended for new deployments due to its speed and strength, though less suited for older systems.

## Generating RSA Keys

To generate a **4096-bit** RSA key pair

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

- `-t rsa` → key type is RSA

- `-b 4096` → key length (**4096** bits for stronger security)

- `-C` → adds a comment (often your **email**)

This will create

- `~/.ssh/id_rsa` → private key

-  `~/.ssh/id_rsa.pub` → public key

## Generating Ed25519 Keys

To generate an Ed25519 key pair

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

- `-t ed25519` → key type is Ed25519

- `-C` → adds a comment (often your **email**)

This will create

- `~/.ssh/id_ed25519` → private key

- `~/.ssh/id_ed25519.pub` → public key

## Verifying the Keys

List your generated keys

```bash
ls ~/.ssh/id_*
```

Check details of a key

```bash
ssh-keygen -lf ~/.ssh/id_rsa.pub
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

## Copying Keys to a Server

To use the public key for SSH login, copy it to the server:

```bash
ssh-copy-id username@<Server-IP>
```

This command adds your public key to the server’s `~/.ssh/authorized_keys`, enabling passwordless login.

## Permission
Change the Keys permission

#### Windows
In Windows change the Key permission

CMD / Powershell Command
```bash
icacls <key_file> /inheritance:r /grant:r <Username>:(F)
```
```bash
icacls test.pem /inheritance:r /grant:r Fahad:(F)
```

#### Linux
```bash
sudo chmod 600 <key_file>
``` 

## Best Practice

**Public key usage:** Add `id_rsa.pub` or `id_ed25519.pub` to the remote server’s `~/.ssh/authorized_keys`.

**Recommendation:** Use Ed25519 unless you must support very old systems.

## 🔒 SSH Key Passphrase
An SSH key passphrase is an additional layer of security applied to the **private SSH key**. It protects the private key from unauthorized use in case the key file is compromised.

#### Benefits
- Protects private key if stolen
- Adds security for laptops and personal systems
- Recommended for production and critical access

#### Drawbacks
- Requires entering passphrase (unless cached)
- Slight inconvenience for automation

In simple terms:
- **Private Key** → Your identity
- **Passphrase** → Password protecting that identity  

> **Note:** Passphrase is applied only to the **private key**, never to the `.pub` file.  

#### Check If an SSH Key Has a Passphrase
```bash
ssh-keygen -y -f <KEY_PATH>
ssh-keygen -y -f ~/.ssh/id_rsa
```

- If prompted for passphrase → key **has a passphrase**
- If public key is printed immediately → key **has no passphrase**

### Change SSH Key Passphrase

To change the passphrase of an existing key:

```bash
ssh-keygen -p -f ~/.ssh/id_rsa
```

### Remove Passphrase From SSH Key

To remove the passphrase (make key passwordless):

```bash
ssh-keygen -p -f ~/.ssh/id_rsa
```

When prompted for new passphrase:

```text
Enter new passphrase (empty for no passphrase):
```

Press **ENTER** without typing anything.

### Add Passphrase to an Existing Key

To add a passphrase to a key that currently has none:

```bash
ssh-keygen -p -f ~/.ssh/id_rsa
```

- Old passphrase → Press ENTER
- New passphrase → Enter desired passphrase

### Using `ssh-agent` to Cache Passphrase

`ssh-agent` allows you to enter the passphrase **once per session**.

#### Start ssh-agent

```bash
eval "$(ssh-agent -s)"
```

#### Add SSH Key

```bash
ssh-add ~/.ssh/id_rsa
```

#### List Loaded Keys

```bash
ssh-add -l
```

> Passphrase is cached **in memory**, Cache is lost after logout or reboot

### SSH-Agent Alias
Create Alias for permenant `ssh-agent`

```bash
alias ssha='eval $(ssh-agent) && ssh-add'
```

Add this alias in the `.bashrc` file

Then use alias `ssha`, which activate the `ssh-agent` session

```bash
ssha
```

## Security Recommendations

| Scenario | Passphrase | ssh-agent |
|--------|------------|-----------|
Personal Laptop | Yes | Yes |
Production Server | Yes | Yes |
CI/CD Pipeline | No | No |
Isolated Automation | Optional | Optional |
