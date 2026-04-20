# WireGuard VPN Setup with Docker Compose
 
> **Stack:** WireGuard · wg-easy · Docker Compose · Ubuntu 22.04 LTS · AWS EC2
 
## SSH Into EC2 Instance
 
```bash
ssh -i /path/to/key.pem ubuntu@<EC2_PUBLIC_IP>
```

## Install Docker & Docker Compose
 
Run the following commands on our EC2 instance:
 
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y
 
# Install Docker using the official convenience script
curl -fsSL https://get.docker.com | sh
 
# Add your user to the docker group
sudo usermod -aG docker $USER
 
# Apply the group change in the current session
newgrp docker

# Install Docker Compose plugin
sudo apt install docker-compose-plugin -y
 
# Verify installations
docker --version
docker compose version
```
 
## Project Structure
 
Create a dedicated directory for the WireGuard setup:
 
```bash
mkdir ~/wireguard && cd ~/wireguard
```
 
Our final directory structure will look like:
 
```
~/wireguard/
├── docker-compose.yml       # Main configuration file
└── wg-easy-data/            # Auto-created: WireGuard config & keys
    ├── wg0.conf
    └── ...
```
 
## Docker Compose Configuration
 
Create the `docker-compose.yml` file:
 
```bash
nano ~/wireguard/docker-compose.yml
```
 
Paste the following configuration:
 
```yaml
volumes:
  wg-easy-data:

services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy
    container_name: wg-easy
    volumes:
      - ./wg-easy-data:/etc/wireguard           # Persist config & keys
    ports:
      - "51820:51820/udp"                          # WireGuard VPN port
      - "51821:51821/tcp"                          # Web UI port
    
    environment:
      # ─── Required ───────────────────────────────────────────
      - LANG=en
      - WG_HOST=<OUR_EC2_PUBLIC_IP_OR_DOMAIN>   # Public IP or domain name
      - PASSWORD_HASH=<YOUR_BCRYPT_HASH>           # See: Generate Password Hash
 
      # ─── WireGuard Settings ─────────────────────────────────
      - WG_PORT=51820
      - PORT=51821
      - WG_DEFAULT_DNS=1.1.1.1,8.8.8.8            # DNS servers for VPN clients
      # - WG_DEFAULT_ADDRESS=10.8.0.x             # VPN subnet (x = auto-assigned)
      # - WG_ALLOWED_IPS=0.0.0.0/0,::/0           # Route ALL traffic through VPN
      # - WG_MTU=1420
      # - WG_PERSISTENT_KEEPALIVE=25              # Keeps NAT connections alive
      # - WG_PRE_UP=echo "Pre Up" > /etc/wireguard/pre-up.txt
      # - WG_POST_UP=echo "Post Up" > /etc/wireguard/post-up.txt
      # - WG_PRE_DOWN=echo "Pre Down" > /etc/wireguard/pre-down.txt
      # - WG_POST_DOWN=echo "Post Down" > /etc/wireguard/post-down.txt
      - ENABLE_PROMETHEUS_METRICS=false
      # - WG_ENABLE_ONE_TIME_LINKS=true
      # - UI_ENABLE_SORT_CLIENTS=true
      # - WG_ENABLE_EXPIRES_TIME=true
 
      # ─── Web UI Settings ────────────────────────────────────
      - UI_TRAFFIC_STATS=true                      # Show traffic stats in UI
      - UI_CHART_TYPE=1                            # 0=None, 1=Line, 2=Area, 3=Bar
 
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
      # - NET_RAW # ⚠ Uncomment if using Podman

    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=0
      - net.ipv6.conf.all.forwarding=1
      - net.ipv6.conf.default.forwarding=1
 
    restart: unless-stopped
```
 
## Generate Password Hash
 
wg-easy requires a **bcrypt hash** — not a plaintext password — for the `PASSWORD_HASH` variable.
 
### Using Docker
 
```bash
docker run --rm ghcr.io/wg-easy/wg-easy wgpw 'OurStrongPassword'
```
 
### Example Output
 
```
PASSWORD_HASH='$2b$12$coPqCsPtcFO.Ab99xylBNOW4.Iu7OOA2/ZIboHN68I9v.k7/9DXFa'
```
 
### Handling `$` Signs in the Hash
 
The bcrypt hash contains `$` characters, which need special handling in Docker Compose:
 
**Method 1 — Escape each `$` with `$$`:**
 
```yaml
environment:
  - PASSWORD_HASH=$$2b$$12$$coPqCsPtcFO.Ab99xylBNO...
```
 
**Method 2 — Use a `.env` file:**
 
```bash
# Create .env file
echo "PASSWORD_HASH=\$2b\$12\$coPqCsPtcFO..." > ~/wireguard/.env
```
 
```yaml
# In docker-compose.yml
environment:
  - PASSWORD_HASH=${PASSWORD_HASH}
```

## Environment Variables Reference
 
| Variable                  | Required | Default         | Description                                      |
|---------------------------|----------|-----------------|--------------------------------------------------|
| `WG_HOST`                 | ✅ Yes   | —               | Public IP or domain of your EC2 instance         |
| `PASSWORD_HASH`           | ✅ Yes   | —               | Bcrypt hash of the Web UI password               |
| `LANG`                    | No       | `en`            | Web UI language                                  |
| `WG_PORT`                 | No       | `51820`         | UDP port for WireGuard                           |
| `WG_DEFAULT_DNS`          | No       | `1.1.1.1`       | DNS servers assigned to VPN clients              |
| `WG_DEFAULT_ADDRESS`      | No       | `10.8.0.x`      | VPN subnet; `x` is auto-assigned per client      |
| `WG_ALLOWED_IPS`          | No       | `0.0.0.0/0`     | Traffic routes — use `0.0.0.0/0` for full tunnel |
| `WG_PERSISTENT_KEEPALIVE` | No       | `0`             | Keepalive interval in seconds (25 recommended)   |
| `UI_TRAFFIC_STATS`        | No       | `false`         | Show per-client traffic statistics               |
| `UI_CHART_TYPE`           | No       | `0`             | Traffic chart style (0=None, 1=Line, 2=Area)     |
 
## Start the VPN Server
 
```bash
cd ~/wireguard
 
# Start the container in detached mode
docker compose up -d
 
# Verify the container is running
docker compose ps
 
# View live logs
docker compose logs -f
```
 
### Expected Output
 
```
[+] Running 1/1
 ✔ Container wg-easy  Started
```
 
## Enable IP Forwarding
 
IP forwarding must be enabled at the **host (EC2) level** to allow VPN traffic routing:

```bash
# Enable immediately (takes effect now)
sudo sysctl -w net.ipv4.ip_forward=1
 
# Make it permanent across reboots
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
 
# Verify it's enabled
sysctl net.ipv4.ip_forward
# Expected output: net.ipv4.ip_forward = 1
```

## Access the Web UI
 
Open oour browser and navigate to:
 
```
http://<EC2_PUBLIC_IP>:51821
```
 
Log in with the password we used to generate the bcrypt hash.
 
### Web UI Features
 
- **Create clients** — generate configs for new devices
- **Download `.conf` files** — for desktop WireGuard clients
- **Scan QR codes** — for mobile devices (iOS/Android)
- **Enable/disable clients** — toggle access without deleting
- **View traffic stats** — monitor per-client bandwidth usage
- **Delete clients** — revoke access permanently
 
---

## Security Group Configuration
 
Configure the following **Inbound Rules** on your EC2 Security Group:
 
| Port        | Protocol | Source        | Purpose                  |
|-------------|----------|---------------|--------------------------|
| `22`        | TCP      | our local IP only  | SSH access               |
| `51820`     | UDP      | 0.0.0.0/0     | WireGuard VPN tunnel     |
| `51821`     | TCP      | our local IP only  | wg-easy Web UI           |
 
> **Security Tip:** Restrict port `51821` (Web UI) to our IP address only. Never expose it to `0.0.0.0/0` in production.
 
## Managing VPN Clients
 
### Adding a New Client
 
1. Open the Web UI at `http://<EC2_PUBLIC_IP>:51821`
2. Click **"+ New Client"**
3. Enter a name (e.g., `my-laptop`, `iphone`, `home-pc`)
4. Click **"Create"**
 
### Connecting a Device
 
**Desktop (Windows/macOS/Linux):**
1. Download the `.conf` file from the Web UI
2. Open WireGuard app → **Import tunnel from file**
3. Toggle the tunnel **ON**
 
**Mobile (iOS/Android):**
1. Click the **QR code icon** next to your client in the Web UI
2. Open WireGuard app → **Add a tunnel → Scan QR code**
3. Toggle the tunnel **ON**
 
### Revoking Client Access
 
1. Open the Web UI
2. Find the client → Click the **delete (trash) icon**
3. Confirm deletion — the client can no longer connect
 
## Useful Docker Commands
 
```bash
# Start the VPN server
docker compose up -d
 
# Stop the VPN server
docker compose down
 
# Restart the container
docker compose restart wg-easy
 
# View live logs
docker compose logs -f wg-easy
 
# Check container status
docker compose ps
 
# Pull latest wg-easy image
docker compose pull
 
# Update to latest version
docker compose pull && docker compose up -d
 
# Enter the container shell
docker exec -it wg-easy bash
 
# Check WireGuard status inside container
docker exec -it wg-easy wg show
```
 
## Troubleshooting
 
### Cannot Access Web UI (port 51821)
 
- Verify the EC2 **Security Group** allows TCP `51821` inbound
- Confirm the container is running: `docker compose ps`
- Check for startup errors: `docker compose logs wg-easy`
 
### VPN Connects but No Internet Access
 
```bash
# Verify IP forwarding is enabled
sysctl net.ipv4.ip_forward
# Must return: net.ipv4.ip_forward = 1
 
# If not, re-enable it
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
```
 
### Password Hash Not Working
 
- Ensure the hash was generated with `wgpw` or `bcryptjs`
- Double-check that every `$` in the hash is escaped as `$$` in `docker-compose.yml`
- Try using a `.env` file instead (see [Generate Password Hash](#generate-password-hash))
 
### Container Fails to Start
 
```bash
# View detailed error logs
docker compose logs wg-easy
 
# Common causes:
# - Port 51820 already in use
# - Missing NET_ADMIN capability
# - Invalid PASSWORD_HASH format
```
 
### Clients Cannot Connect to VPN
 
- Confirm **UDP port 51820** is open in the Security Group
- Verify `WG_HOST` matches the actual public IP of your EC2 instance
- If using an Elastic IP, ensure the compose file is updated and container restarted
- Check WireGuard status: `docker exec -it wg-easy wg show`
 
### DNS Not Resolving Through VPN
 
- Verify `WG_DEFAULT_DNS` is set to valid DNS servers (e.g., `1.1.1.1,8.8.8.8`)
- Recreate the client config after changing DNS settings
 