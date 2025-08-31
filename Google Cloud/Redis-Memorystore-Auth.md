# Creating Redis (Cloud Memorystore) in GCP with AUTH Enabled

## Overview
This guide explains how to create a Google Cloud Memorystore for Redis instance with AUTH (password protection) enabled. This setup allows your applications to securely connect to Redis using a password.

## Prerequisites
- A Google Cloud project with billing enabled.
- A VPC network (e.g., default or a custom one)
- A GCP VM or service in the same region and VPC as Redis for connectivity

## Steps to Create Redis with AUTH Enabled

### Step 1: Open the Memorystore Console
- Go to **MemoryStore for Redis Console**
- Click on **Create Instance** at the top.

### Step 2: Fill in Basic Configuration
- Enter the **Name** and **Display Name**  
- Select **Region** (same as your VM)  
- Select **Zone** (e.g., `asia-southeast1-a`)  
- Select the **Tier** (Standard or Basic)  
- Set the **Memory Capacity** (e.g., `1 GiB` for testing)  
- In **Set Up Connection** select the **VPC** (same as your VM)  

### Step 3: Configure Connections
- Select **Direct Peering**  
 Your VM must be in the same VPC to connect to Redis.  

### Step 4: Security
In the **Security** section enable AUTH for password.

- **Enable AUTH**  
  - Check **Enable AUTH**  
  - GCP will generate a strong password for the Redis instance  
  - You can retrieve this password later from the instance details page  

> **Important Note**: Leave *Enable in-transit encryption* unchecked unless you specifically need TLS encryption for your setup.  

- **Encryption at Rest**  
  - Leave as **Google-managed encryption key**  

### Step 5: Redis Version
- Select your **Redis Version**  

Finally, click **Create Instance**.  
GCP will provision the instance (may take **2–5 minutes**).


## Retrieving the AUTH Password
After the instance is created:

1. Go to your Redis instance in **GCP Console**
2. Scroll to **Security** section
3. Click **View** next to AUTH string
4. Copy the password and store it securely

## Connecting to Redis with Password

From a VM inside the same VPC, you can connect using:

```bash
redis-cli -u redis://default:<AUTH_PASSWORD>@<REDIS_PRIVATE_IP>:6379 ping
```

### Example:
```bash
redis-cli -u redis://default:my-secret-password@10.146.149.59:6379 ping
```

Expected response:
```
PONG
```

OR using the alternative method:

```bash
redis-cli -h <REDIS_PRIVATE_IP> -p 6379 -a <AUTH_STRING> ping
```

Expected response:
```
PONG
```
