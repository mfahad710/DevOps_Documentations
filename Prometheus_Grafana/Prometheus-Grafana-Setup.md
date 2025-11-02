# Prometheus & Grafana Setup Guide

## Prometheus

We are configuring our monitoring on the Redhat Server.

**Connect to the Server via SSH and run the following commands.**

```bash
sudo yum update -y
sudo yum install wget tar -y
```

Create Prometheus User

```bash
sudo useradd --no-create-home --shell /bin/false prometheus
```

Create Prometheus Directories

```bash
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
```

Set Permission

```bash
sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus
```

Download and Extract Prometheus

Visit [Prometheus Downloads](https://prometheus.io/download/) for the latest version.

```bash
cd /tmp
sudo wget https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz
sudo tar xvf prometheus-3.5.0.linux-amd64.tar.gz
cd prometheus-3.5.0.linux-amd64
```

Move Binaries and Set Permissions

```bash
sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/

sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
```

Move Configuration Files

```bash
sudo cp -r consoles /etc/prometheus
sudo cp -r console_libraries /etc/prometheus
sudo cp prometheus.yml /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus
```

Edit the Configuration File

```bash
sudo nano /etc/prometheus/prometheus.yml
```

Default scrape:

```bash
global:
scrape_interval: 15s

scrape_configs:
- job_name: 'prometheus'
static_configs:
- targets: ['localhost:9090']
```

Create a Systemd Service

```bash
sudo nano /etc/systemd/system/prometheus.service
```

Paste this:

```bash
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus --web.console.templates=/etc/prometheus/consoles --web.console.libraries=/etc/prometheus/console_libraries
Restart=always

[Install]
WantedBy=multi-user.target
```


Start and Enable the Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
```

Check status:

```bash
sudo systemctl status prometheus
```

Hit the URL via browser: ***http://<SERVER_IP>:9090***


## Node Exporter

Node Exporters are commonly used to monitor system-level application insights. The tool specifically provides node and container statistics, which allow developers to analyse real-time metrics of containers and nodes.

Download the Latest Node Exporter Binary

Go to [Prometheus → Node Exporter](https://prometheus.io/download/#node_exporter) Releases for the latest version

```bash
cd /tmp
sudo wget https://github.com/prometheus/node_exporter/releases/download/v1.9.0/node_exporter-1.9.0.linux-amd64.tar.gz
sudo tar xvf node_exporter-1.9.0.linux-amd64.tar.gz
cd node_exporter-1.9.0.linux-amd64
```

Create a Dedicated User

```bash
sudo useradd --no-create-home --shell /bin/false node_exporter
```

Move Binary to System Path

```bash
sudo cp node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
```

Create a Systemd Service File

```bash
sudo nano /etc/systemd/system/node_exporter.service
```

Paste this:

```bash
[Unit]
Description=Prometheus Node Exporter UAT NGINX
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

Restart=always

[Install]
WantedBy=multi-user.target
```

Start and Enable Node Exporter

```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

Check its status:
```bash
sudo systemctl status node_exporter
```

Open in browser:
http://SERVER_IP:9100/metrics → you should see raw metrics.  
In Prometheus (http://SERVER_IP:9090), go to Status → Targets and check if node-exporter:9100 is UP.

Add the **node_exporter** job in Prometheus configuration file

```bash
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['10.4.60.2:9100']
```

Restart Prometheus to apply:

```bash
sudo systemctl restart prometheus
```

Import Node Exporter Dashboards on Grafana after the installation of
Grafana

Grafana has ready-made dashboards for Node Exporter.

-   In Grafana left menu → + (Create) → Import Dashboard.
-   Enter this ID from Grafana.com dashboards:
-   **1860** → Node Exporter Full (most popular).
-   Click Load, then select your Prometheus data source.
-   Click **Import**.

## Grafana

Import the GPG key:

```bash
wget -q -O gpg.key https://rpm.grafana.com/gpg.key
sudo rpm --import gpg.key
```

Create /etc/yum.repos.d/grafana.repo with the following content:

```bash
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
```

Verify:
```bash
yum repolist | grep grafana
```

We should see grafana listed.

To install Grafana OSS

```bash
sudo dnf install grafana -y
```

OR

```bash
sudo yum install grafana -y
```

This installs:
- Binaries in `/usr/sbin/grafana-server`
- Config file in `/etc/grafana/grafana.ini`
- Data directory in `/var/lib/grafana`

Review & Adjust Configuration

```bash
sudo nano /etc/grafana/grafana.ini
```

Useful settings:

```bash
[server]
http_port = 3000
root_url = %(protocol)s://%(domain)s:%(http_port)s/
;domain = your-hostname.example.com\

[security]
admin_user = admin
admin_password = admin
```

Start and Enable the Service

```bash
sudo systemctl daemon-reload\
sudo systemctl enable grafana-server\
sudo systemctl start grafana-server
```

Check status:

```bash
sudo systemctl status grafana-server
```
Access Grafana Web Interface

Default credentials:

```bash
Username: admin
Password: admin
```

Connect Grafana to Prometheus

- Login **Grafana** → **Connection** → **Data Sources** → **Add Data Sources**
- Give the Name: **Prometheus**
- Select **Prometheus** as Data Source
- Add URL: ***http://SERVER_IP:9090***
- Save



## Loki + Promtail

**Loki** (for log aggregation) and **Promtail** (for log collection).

### Loki

Create Users and Directories

```bash
sudo useradd --no-create-home --shell /bin/false loki

sudo mkdir -p /etc/loki
sudo mkdir -p /var/lib/loki

sudo chown loki:loki /etc/loki
sudo chown loki:loki /var/lib/loki
```

Download Binary

```bash
cd /tmp
sudo wget https://github.com/grafana/loki/releases/download/v3.5.5/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
sudo mv loki-linux-amd64 /usr/local/bin/loki
sudo chmod +x /usr/local/bin/loki
sudo chown loki:loki /usr/local/bin/loki
```

Create Loki Configuration

Configuration file Link:
<https://grafana.com/docs/loki/latest/configure/examples/configuration-examples/>

```bash
sudo nano /etc/loki/loki-config.yaml

sudo chown loki:loki /etc/loki/loki-config.yaml
```

Paste this:

```bash
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
```

Create Loki Systemd Service

```bash
sudo nano /etc/systemd/system/loki.service
```

Paste:

```bash
[Unit]
Description=Loki Log Aggregation
Wants=network-online.target
After=network-online.target

[Service]
User=loki
Group=loki
ExecStart=/usr/local/bin/loki --config.file=/etc/loki/loki-config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
```

Start and Enable Loki

```bash
sudo systemctl daemon-reload
sudo systemctl enable loki
sudo systemctl start loki
sudo systemctl status loki
```
Check through browser URL:  
http://SERVER_IP:3100/metrics  
http://SERVER_IP:3100/ready

You should see HTTP 200 OK.

**Configure Grafana to Use Loki**

- Go to http://SERVER_IP:3000 → Login with your admin user/pass.

- Login **Grafana** → **Connection** → **Data Sources** → **Add Data Sources**
- Give the Name: **Loki**
- Select **Loki** as Data Source
- Add URL: http://SERVER_IP:3100
- Click Save & Test

Now you can go to Explore → Loki and see logs!

### Promtail

Create Users and Directories

```bash
sudo useradd --no-create-home --shell /bin/false promtail

sudo mkdir -p /etc/promtail

sudo chown promtail:promtail /etc/promtail
```

Download Binary

```bash
cd /tmp
sudo wget https://github.com/grafana/loki/releases/download/v3.5.5/promtail-linux-amd64.zip
sudo unzip promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/promtail
sudo chown promtail:promtail /usr/local/bin/promtail
```

Create Promtail Configuration

```bash
sudo nano /etc/promtail/promtail-config.yaml

sudo chown promtail:promtail /etc/promtail/promtail-config.yaml
```

Paste this configuration:

```bash
server: 
  http_listen_port: 9080 
  grpc_listen_port: 0 

positions: 
  filename: /tmp/positions.yaml 

clients: 
  - url: http://SERVER_IP:3100/loki/api/v1/push 

scrape_configs: 
- job_name: system 
  static_configs: 
  - targets: 
      - Localhost 
    labels: 
      job: varlogs 
      host: server-SERVER_IP
      __path__: /var/log/*log 

- job_name: nginx 
  static_configs: 
  - targets: 
      - localhost 
    labels: 
      job: nginx-logs 
      __path__: /var/log/nginx/*.log 
```


Create Promtail Systemd Service

```bash
sudo nano /etc/systemd/system/promtail.service
```

Paste:

```bash
[Unit]
Description=Promtail Log Collector
After=network.target

[Service]
User=promtail
Group=promtail
ExecStart=/usr/local/bin/promtail --config.file=/etc/promtail/promtail-config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
```

Start and Enable Promtail

```bash
sudo systemctl daemon-reload
sudo systemctl enable promtail
sudo systemctl start promtail
sudo systemctl status promtail
```

## Alertmanager

Alertmanager is part of the Prometheus stack. It handles alerts, routes them to email/Slack, and manages deduplication and silencing.

Create Alertmanager User

```bash
sudo useradd --no-create-home --shell /bin/false alertmanager
```

Download Alertmanager Binary

```bash
cd /opt
sudo wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
sudo tar -xvf alertmanager-0.27.0.linux-amd64.tar.gz
sudo mv alertmanager-0.27.0.linux-amd64 alertmanager
```

Move Binaries

```bash
sudo cp /opt/alertmanager/alertmanager /usr/local/bin/
sudo cp /opt/alertmanager/amtool /usr/local/bin/
sudo chown alertmanager:alertmanager /usr/local/bin/alertmanager /usr/local/bin/amtool
```

Create Configuration Directory

```bash
sudo mkdir /etc/alertmanager
sudo mkdir /var/lib/alertmanager
sudo chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager
```

Create Configuration File

```bash
sudo nano /etc/alertmanager/alertmanager.yml
```

Config File:

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: 'email-alert'

receivers:
  - name: 'email-alert'
    email_configs:
      - to: 'alerts@yourdomain.com'
        from: 'alertmanager@yourdomain.com'
        smarthost: 'smtp.yourdomain.com:587'
        auth_username: 'alertmanager@yourdomain.com'
        auth_password: 'yourpassword'
```

Create Systemd Service

```bash
sudo nano /etc/systemd/system/alertmanager.service
```

Content:
```ini
[Unit]
Description=Prometheus Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/usr/local/bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml --storage.path=/var/lib/alertmanager
Restart=always

[Install]
WantedBy=multi-user.target
```

Reload and Start Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable alertmanager
sudo systemctl start alertmanager
sudo systemctl status alertmanager
```

Access through Browser

```bash
http://<your-server-ip>:9093
```

Integrate with Prometheus

Add in `/etc/prometheus/prometheus.yml`:

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - "localhost:9093"
```

Then restart Prometheus:
```bash
sudo systemctl restart prometheus
```
