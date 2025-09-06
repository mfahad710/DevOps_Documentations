# SSL Branded Links for SendGrid

## Set Up SSL Link Branding with SendGrid and Nginx

**Fortrans** uses SendGrid as the default email sender for all the customers.  
All the clickable links in the email are converted to the SendGrid domain for click tracking, but the clicks are ultimately redirected to our website.  

If our customers observe the links before clicking on them, they will see `sendgrid.com/some-landing-page` rather than `ourdomain.com/some-landing-page`.  
Opt-in for Link branding if we want the links to be displayed as `ourdomain.com`.

## Setup Link Branding

From our Sendgrid dashboard:

1. Go to **Settings > Sender Authentication**. Then go to the **Link Branding** section and click **Brand your links**.
2. Select your **DNS provider** and click **Next**.
3. In the **From Domain** input, add your custom domain (e.g., `fortrans.com`).
4. Under **Advanced Settings**, select **Use a custom link subdomain** and fill the **Return path**.  
   Example: if we use `mail`, our custom subdomain will be `mail.fortrans.com`.
5. Click **Next**. Sendgrid will provide DNS records to add in your DNS provider.
6. After adding CNAME records in the DNS provider, click **Verify**.

## Add HTTPS

After these steps, link branding should work properly. Links in new emails should start with your custom subdomain.  

However, you will notice the links are served through **HTTP** and not **HTTPS**.  
For example:  
- `http://mail.fortrans.com` instead of  
- `https://mail.fortrans.com`  

Some browsers (including Chrome) block insecure links.  

### Why HTTPS is Disabled by Default?
SendGrid disables HTTPS because CNAME forwarding from `mail.fortrans.com` → `sendgrid.net` prevents SSL termination (SendGrid would require a valid SSL certificate for your domain).

### Solution
We must forward traffic to `sendgrid.net` via **our own Nginx server**, with SSL enabled.

## Create an NGINX Web Server

1. Create or use an existing **VM/Server**.  
2. Install Nginx:
   ```bash
   sudo apt install nginx
   ```
3. Create an **A record** in your DNS provider:  
   - Point `sendgrid.fortrans.com` → VM IP.

After this, your Nginx server should be accessible at `sendgrid.fortrans.com`.

## Create an Nginx Rule

Create a new Nginx configuration file:

```bash
sudo nano /etc/nginx/sites-available/sendgrid.fortrans.com
```

Add the following content:

```nginx
server {
    listen 80;
    server_name mail.fortrans.com;

    location / {
        proxy_pass http://sendgrid.net; 
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the configuration:

```bash
sudo ln -s /etc/nginx/sites-available/sendgrid.fortrans.com /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## SSL with Certbot and Nginx

### Option 1: Use Certbot (Let's Encrypt)

Install Certbot:

```bash
sudo apt update
sudo apt install certbot python3-certbot-nginx
```

Obtain SSL:

```bash
sudo certbot --nginx -d mail.fortrans.com
```

Verify certificates:

```bash
sudo certbot certificates
```

---

### Option 2: Use Existing SSL Certificates

If you already have SSL certificates, use this configuration:

```nginx
server {
    listen 80;
    server_name mail.fortrans.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    ssl_certificate /etc/ssl/fort/fort_plus_intermediateCA.crt;
    ssl_certificate_key /etc/ssl/fort/fort.key;
    ssl_trusted_certificate /etc/ssl/fort/intermediateCA_rootCA_trustChain.crt;

    server_name mail.fortrans.com;

    location / {
        proxy_pass http://sendgrid.net; 
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Restart Nginx:

```bash
sudo systemctl restart nginx
```

## Update DNS CNAME Record

1. Open the **CNAME record** for `mail.fortrans.com`.
2. Change the CNAME to point to `sendgrid.fortrans.com` instead of `sendgrid.net`.
3. Do **NOT** revalidate DNS in SendGrid.

Test by opening any link in sent emails.

## Contact SendGrid

After configuration, contact **SendGrid Support** and request **SSL enablement** for your custom domain.

## Reference

[MoEngage - Configure SSL Branded Links for SendGrid](https://help.moengage.com/hc/en-us/articles/19156797325588-Configure-SSL-Branded-Links-for-SendGrid#h_01HQ0S48XE9WZTX81Q4JESC6X7)
