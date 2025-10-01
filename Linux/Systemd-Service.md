# Create a systemd Service

To create and manage a **systemd service** to run your applications (Java, Spring Boot, Python, Node.js, etc.) as background services on Linux.

## 1. Create a Service File
Systemd service files are stored in `/etc/systemd/system/`.

```bash
sudo nano /etc/systemd/system/myapp.service
```

## 2. Example Service File

```yaml
[Unit]
Description=My Custom Application Service
After=network.target

[Service]
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/java -jar /opt/myapp/myapp.jar

Restart=always
RestartSec=10

# Run as a specific user
User=root

# Redirect logs
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

## 3. Reload systemd
After creating the service file, reload systemd to recognize it:

```bash
sudo systemctl daemon-reload
```

## 4. Enable the Service (Start on Boot)
```bash
sudo systemctl enable myapp.service
```

## 5. Start the Service
```bash
sudo systemctl start myapp.service
```

## 6. Check Status & Logs
```bash
sudo systemctl status myapp.service
```

To follow logs in real time:
```bash
journalctl -u myapp.service -f
```

> Now our app will run in the background and automatically restart on system reboot.
