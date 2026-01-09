# Docker Installation Guide 

To install Docker on a Red Hat (RHEL) machine with **NO internet access**, we need to do an offline (air-gapped) installation using docker binaries.

### Install Static Binaries
Download the static binary archive. Go to [Docker Binaries](https://download.docker.com/linux/static/stable/), choose your **hardware platform**, and download the `.tgz` file relating to the version of Docker Engine you want to install.

**SCP tar file into the server**

Extract the archive using the tar utility. The dockerd and docker binaries are extracted.

```bash
tar xzvf /path/to/FILE.tar.gz
```

Optional: Move the binaries to a directory on your executable path, such as `/usr/bin/`. If you skip this step, you must provide the path to the executable when you invoke docker or dockerd commands.

```bash
sudo cp docker/* /usr/bin/
```

Start the Docker daemon:

```bash
sudo dockerd &
```

Ensure these binaries exist:

```bash
which docker
which dockerd
```

You have now successfully installed and started Docker Engine.

### Create systemd Service File

Create the service unit:

```bash
sudo vi /etc/systemd/system/docker.service
```

Add the following content in the file

```bash
[Unit]
Description=Docker Container Engine
Documentation=https://docs.docker.com
After=network.target firewalld.service
Requires=containerd.service
 
[Service] 
ExecStart=/usr/bin/dockerd --host=unix:///var/run/docker.sock --containerd=/run/containerd/containerd.sock 
 
ExecReload=/bin/kill -s HUP $MAINPID 
TimeoutStartSec=0 
Restart=on-failure
RestartSec=5
 
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
 
Delegate=yes
KillMode=process
OOMScoreAdjust=-500
 
[Install]
WantedBy=multi-user.target
```


#### Create containerd systemd Service (Required) 

Docker depends on containerd, even with static binaries. 
Create service file 

```bash
sudo vi /etc/systemd/system/containerd.service
```

Add the following content in the file

```bash
[Unit] 
Description=containerd container runtime 
Documentation=https://containerd.io 
After=network.target local-fs.target
 
[Service] 
ExecStart=/usr/bin/containerd 
Restart=always 
RestartSec=5 
 
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
 
[Install]
WantedBy=multi-user.target

```

Reload systemd and Start Services

```bash
sudo systemctl daemon-reexec 
sudo systemctl daemon-reload
sudo systemctl enable containerd docker
sudo systemctl start containerd docker
```

Check status:

```bash
systemctl status docker 
systemctl status containerd
```

