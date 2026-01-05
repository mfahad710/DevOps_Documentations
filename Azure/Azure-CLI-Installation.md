# Azure CLI Installation Guide

This document provides instructions for installing Azure CLI on Ubuntu and RedHat/CentOS systems.

## Ubuntu Installation

Update system packages

```bash
sudo apt update
```
Install dependencies

```bash
sudo apt install -y ca-certificates curl apt-transport-https lsb-release gnupg
```

Add Microsoft GPG key

```bash
curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
```

Add Azure CLI repository
```bash
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
sudo tee /etc/apt/sources.list.d/azure-cli.list
```

Install Azure CLI
```bash
sudo apt update
sudo apt install -y azure-cli
```

## RedHat/CentOS Installation

Install required packages
```bash
sudo yum install -y ca-certificates curl gnupg
```

Import Microsoft repository GPG key
```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
```

Add Azure CLI repository
```bash
sudo sh -c 'echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
```

Install Azure CLI
```bash
sudo yum install -y azure-cli
```

## Verify Installation
```bash
az version
```

## Login to Azure
```bash
az login
```

For headless servers or CI/CD environments:
```bash
az login --use-device-code
```

## Upgrade Azure CLI
#### Ubuntu
```bash
sudo apt update && sudo apt upgrade azure-cli
```

#### RedHat/CentOS
```bash
sudo yum update azure-cli
```

## Uninstall Azure CLI
#### Ubuntu
```bash
sudo apt remove -y azure-cli
```

#### RedHat/CentOS
```bash
sudo yum remove -y azure-cli
```

