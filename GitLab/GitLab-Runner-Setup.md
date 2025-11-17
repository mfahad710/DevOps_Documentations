# GitLab Runner Setup on Linux Server

**Runners** are the agents that run our jobs. These agents can run on physical machines or virtual instances. In our `.gitlab-ci.yml` file, we can specify a container image we want to use when running the job. The runner loads the image, clones our project, and runs the job either locally or in the container.

If we use `GitLab.com`, runners on Linux, Windows, and macOS are already available for use. If needed, we can also register our own runners.

If we don’t use  `GitLab.com`, we can:
- Register runners or use runners already registered for our GitLab Self-Managed instance.
- Create a runner on our local machine.

This guide explains how to install and configure GitLab Runner on a Linux server.

## Prerequisites
- A Linux server (Ubuntu, Debian, RHEL, CentOS, Fedora).
- Root or `sudo` privileges.
- GitLab instance URL (self-hosted or GitLab.com).
- Runner registration token from GitLab (Project, Group, or Instance).

## Create a Dedicated User (Recommended)
It's a good security practice to run GitLab Runner under a dedicated user:

```bash
# Create a gitlab-runner user
sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash

# Verify the user exists
id gitlab-runner
```

## Install GitLab Runner

**Official Installation Page**  
[GitLab Runner Installation Link](https://docs.gitlab.com/runner/install/)


### On Debian/Ubuntu
```bash
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner -y
```

### On RHEL/CentOS
```bash
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
# Install GitLab Runner
sudo yum install gitlab-runner -y
# OR for newer versions
sudo dnf install gitlab-runner
```

---

> If we don't have access to the internet on the server so first we download the Runner binaries in the system that has internet access and then secure copy the binaries on the server.

**Download the binary on Internet accessed machine**  
```bash
sudo curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
```

It will download the gitlab-runner file in the `/usr/local/bin/` directory

Then Secure Copy (**scp**) the file to the GitLab server

```bash
scp /usr/local/bin/gitlab-runner <Username>@<Server_IP>:/usr/local/bin/
```

**Give it permission to execute**

```bash
sudo chmod +x /usr/local/bin/gitlab-runner
```

**Install and run as a service**  

```bash
sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
sudo gitlab-runner start
```


## Verify Installation
```bash
gitlab-runner --version
```

## Register the Runner
```bash
sudo gitlab-runner register
```
You'll be prompted with several questions:
- **GitLab URL**: e.g., `https://gitlab.com/` or `http://your-gitlab-server/`
- **Token**: From GitLab CI/CD settings
- **Description**: e.g., `my-linux-runner`
- **Tags**: e.g., `docker, linux`
- **Executor**: Choose `docker` or `shell`

If you chose `docker` executor, you need Docker installed on the server and select the default image `alpine:latest`  or `ruby`

## Check Runner Status
```bash
sudo gitlab-runner list
sudo gitlab-runner status
```

## Enable and Start Runner
```bash
sudo systemctl enable gitlab-runner
sudo systemctl start gitlab-runner
sudo systemctl status gitlab-runner
```

## Configure Runner

The main configuration file is located at `/etc/gitlab-runner/config.toml`. We can edit it directly for advanced settings:

If we want to edit the file

```bash
sudo nano /etc/gitlab-runner/config.toml
```

**Example File**:  
```toml
concurrent = 4
check_interval = 0

[session_server]
  listen_address = "[::]:8093"
  advertise_address = "your-server-ip:8093"
  session_timeout = 1800

[[runners]]
  name = "dedicated-server-runner"
  url = "https://gitlab.example.com/"
  token = "YOUR_RUNNER_TOKEN"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
```

## Test with Sample Pipeline

Create `.gitlab-ci.yml`:  

```yaml
stages:
  - build

build-job:
  stage: build
  tags:
    - <Runner_Tag>
  script:
    - echo "Runner is working!"
    - uname -a
```

Push to GitLab → CI/CD job should run successfully.

