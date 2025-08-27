---

# Generating SSH Key Pairs

## Introduction

In cryptography, a key pair consists of

- **Private key** → kept secret, used for authentication/signing.

- **Public key** → shared openly, used for verification/encryption.

SSH (**Secure Shell**) commonly uses public-key cryptography for secure access to servers. Two popular algorithms are

- **RSA (Rivest–Shamir–Adleman)**

RSA is a widely used algorithm based on **prime factorization**. Keys range from **2048** to **4096** bits, with larger sizes offering stronger security. It is slower in signing and verification but highly compatible across all systems, making it useful where legacy support is needed.

- **Ed25519 (Edwards-curve Digital Signature Algorithm 25519)**

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

## Best Practice

**Permissions:** Ensure private keys are `chmod 600`.

**Public key usage:** Add `id_rsa.pub` or `id_ed25519.pub` to the remote server’s `~/.ssh/authorized_keys`.

**Recommendation:** Use Ed25519 unless you must support very old systems.

---