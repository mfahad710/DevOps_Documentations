# Nginx Security Hardening & Header Configuration

## Overview

This document provides a guide to secure Nginx by adding security headers and adjusting security-related settings in Debian base Linux distros

## Edit Nginx Configurations

Edit your site-specific configuration file located at:

```bash
sudo nano /etc/nginx/sites-available/your-site-config
```

Or the global config file:

```bash
sudo nano /etc/nginx/nginx.conf
```

### Add Security Headers

Add the following lines inside the server or location block:

```bash
# Prevent clickjacking
add_header X-Frame-Options "SAMEORIGIN" always;

# Prevent MIME-type sniffing
add_header X-Content-Type-Options "nosniff" always;

# XSS protection
add_header X-XSS-Protection "1; mode=block" always;

# Control Referrer information
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# Enforce HTTPS
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

# Content Security Policy
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; object-src 'none';" always;

# Remove Nginx version
server_tokens off;
```

> **Note: Modify the headers according to requirements**

#### Test & Reload Nginx

After editing configuration files:

```bash
# Test the configuration
sudo nginx -t

# Reload the service
sudo systemctl reload nginx
```

### Security Headers Link

[How to Configure Security Headers in Nginx](https://linuxcapable.com/how-to-configure-security-headers-in-nginx/)

[HTTP Headers - OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html)


## Server Block Example

This is the nginx file that we configure for JLI in their link branding

```bash
server {
    server_name mail.fortrans.com;

    # Add HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    # Add Content-Security-Policy
    add_header Content-Security-Policy "default-src 'self' mail.fortrans.com *.sendgrid.net; script-src 'self' https://mail.fortrans.com/ https://cdn.lr-intake.com/ https://cdn.lr-in-prod.com/ https://www.gstatic.com/ https://www.google.com/recaptcha/ https://www.googletagmanager.com/ https://cdnjs.cloudflare.com/ https://unpkg.com/; worker-src 'self' blob: https://unpkg.com/; img-src 'self' data: *.sendgrid.net; style-src 'self' 'unsafe-inline'; connect-src 'self' *.sendgrid.net;" always;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        proxy_pass http://sendgrid.net; 
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/mail.fortrans.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/mail.fortrans.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if ($host = mail.fortrans.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    listen 80;
    server_name mail.fortrans.com;
    return 404; # managed by Certbot
}
```


# Hiding the "server: nginx" Header in Response

To hide the "server: nginx" field in the HTTP response headers, we need to modify our Nginx server configuration.

Edit Nginx configuration file (typically located at **/etc/nginx/nginx.conf** or in our site's configuration file under **/etc/nginx/sites-available/**)

## Solution

Here are two methods to remove the Server header

### Method 1: 

Use **server_tokens off** (Built-in Nginx Option)

This won't fully remove the Server header but will hide the Nginx version.

Edit the Nginx config:

```bash
sudo nano /etc/nginx/nginx.conf
```

Add inside the http block:

```bash
http {
    server_tokens off;
    ...
}
```

**Test & reload:**

```bash
sudo nginx -t
sudo systemctl reload nginx
```

**Result:**

The header will now show just Server: nginx (without version details).

### Method 2: 

Fully Remove the Server Header (Requires `ngx_headers_more`)

If we need to completely remove the Server header, follow these steps:

**Step 1:**

Install `libnginx-mod-http-headers-more-filter`

```bash
sudo apt update
sudo apt install libnginx-mod-http-headers-more-filter
```

**Step 2:**

Load the Module in `nginx.conf`

```bash
sudo nano /etc/nginx/nginx.conf
```

Add at the top of the file:

```bash
load_module modules/ngx_http_headers_more_filter_module.so;
```

Add this in server block in file

```bash
# Hide server information
server_tokens off;
more_clear_headers Server;
```

**Step 3:**

Remove the Server Header

Inside your server block, add:
```bash
server {
    listen 443 ssl;
    server_name mail.fortrans.com;
    more_clear_headers Server; # Removes the Server header completely
    ...
}
```

**Step 4:**

Test & Reload
```bash
sudo nginx -t
sudo systemctl reload nginx
```

**Step 5: Verify**

Run a curl test:
```bash
curl -I https://mail.fortrans.com
```

The Server header should now be completely gone.

## Final Notes

-   server_tokens off is the simplest solution (hides version but keeps `Server: nginx`).
-   more_clear_headers removes the header entirely but requires an extra module.
-   If still get errors, ensure the module is properly loaded in `nginx.conf`
