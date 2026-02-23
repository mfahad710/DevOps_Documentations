# 🔒SSL Certificate Management with Certbot on Nginx (Ubuntu)

## Overview 
This document provides step-by-step instructions for:
-  Installing Certbot on Ubuntu VM.
- Issuing SSL certificates for Nginx
- Automatically renewing certificates
- Removing existing certificates

## Prerequisites 
- Ubuntu server (20.04 or later)
- Nginx installed and running 
- Domain name pointed to your server's public IP
- `sudo` privileges on the server

## Connect to Server
First connect to the server through **SSH**

```bash
ssh -i /path/to/key username@host
```
## Install Nginx

Install Nginx on server

```bash
sudo apt-get update
sudo apt install nginx
```

## Install Certbot

Install Certbot

```bash
sudo apt install certbot python3-certbot-nginx -y
```

## Nginx Configuration 

Go to **nginx** configuration folder,

```bash
cd /etc/nginx/sites-available
```

Create nginx file by,

```bash
sudo touch api.fortrans.com
```

Open the file in editor

```bash
sudo nano api.fortrans.com
```

Add the following in `api.fortrans.com` file

```bash
server {
    listen 80;
    server_name api.fortrans.com;

    client_max_body_size 25M;

    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Save the file.

create soft link of the file by,

```bash
sudo ln -s /etc/nginx/sites-available/api.fortrans.com /etc/nginx/sites-enabled
```

then test config:

```bash
sudo nginx -t 
```

If Nginx Syntax is **OK** then relaod nginx

```bash
sudo systemctl reload nginx
```

**Note: Before issue a certificate please make sure you set the DNS. create DNS records api.fortrans.com to the server IP.**

## Issue an SSL Certificate

Use the command to request and install a certificate:

```bash
sudo certbot --nginx -d api.fortrans.com
```

You'll be prompted for:

- Email
- Agreement to terms
- Whether to redirect HTTP to HTTPS (usually say "yes")

Certbot will:
- Request a certificate from Let's Encrypt.
- Automatically configure Nginx

## Automatic Renewal 
Let's Encrypt certificates are valid for **90 days**. Certbot installs a system timer to auto-renew certificates.

### Verify Auto-Renewal is Enabled

```bash
systemctl list-timers | grep certbot
```

### Test Renewal

```bash
sudo certbot renew --dry-run
```

## Remove an SSL Certificate 

To delete a certificate issued by Certbot:

**Step 1: List Certificates**

```bash
sudo certbot certificates
```

Find the certificate name, (e.g., `api.fortrans.com`)

**Step 2: Delete Certificate**

```bash
sudo certbot delete --cert-name api.fortrans.com
```

**Step 3: Update Nginx Configuration**

Edit the relevant server block (in `/etc/nginx/sites-available/`) and remove or comment out the SSL lines:

```bash
# ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
# ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;`
```

Change `listen 443 ssl;` to `listen 80;` if needed. 

Then test and reload Nginx:

```bash
sudo nginx -t 
sudo systemctl reload nginx
```

## Check Certificate Information
To view certificate issuer and expiry:

```bash
echo | openssl s_client -connect api.fortrans.com -servername api.fortrans.com | openssl x509 -noout -issuer -enddate
```

## Clean Up Unused Cert Files 
Certbot stores certificates in:
- `/etc/letsencrypt/live/`
- `/etc/letsencrypt/archive/`
- `/etc/letsencrypt/renewal/`

These are removed automatically when using `certbot delete`.
