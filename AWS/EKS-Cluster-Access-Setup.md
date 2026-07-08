# AWS EKS Cluster Access Setup Guide

This document explains how we can get access to the AWS EKS cluster

## Step 1: Create IAM Access Key
- Login to AWS Console.
- Navigate to:
```bash
IAM → Users → fahad@neem.io → Security credentials
```

- Under Access keys, click: `Create access key`
- Choose: Command Line Interface (CLI)
- Copy and securely store:
    - Access Key ID
    - Secret Access Key

## Step 2: Configure AWS CLI on Operator Server

SSH into the Operator server used for EKS access.

- Run:
```bash
aws configure
```

- Enter:
```bash
AWS Access Key ID: <access-key-id>
AWS Secret Access Key: <secret-access-key>
Default region name: <region-code>
Default output format: json
```

## Step 3: Verify AWS Authentication

Run:
```bash
aws sts get-caller-identity
```


Expected output:
```bash
{
 "UserId": "XXXXXXXXXXXX",
 "Account": "123456789012",
 "Arn": "arn:aws:iam::123456789012:user/username"
}
```

This confirms the IAM credentials are configured correctly.

## Step 4: Configure Kubernetes Context for EKS

- Run:
```bash
aws eks update-kubeconfig --region <region-code> --name <cluster-name>
```

Example:
```bash
aws eks update-kubeconfig --region ap-southeast-1 --name neem-stg-eks
```

This updates the kubeconfig file:
```bash
~/.kube/config
```

## Step 5: Add Cluster Access Entry

- In AWS Console, navigate to:
```bash
EKS → Clusters → <cluster-name> → Access
```

- Open the Access tab.
- Click: `Create IAM access entry`
- Add the **IAM user / role** that requires access.
- Assign the appropriate access policy.
    - Recommended for DevOps admins: `AmazonEKSClusterAdminPolicy`
- Access scope: **Cluster**
- Save the entry.

## Step 6: Verify Kubernetes Access

- Run:
```bash
kubectl get ns
```

Expected output:
```bash
NAME              STATUS   AGE
default           Active   10d
kube-system       Active   10d
kube-public       Active   10d
```

This confirms successful access to the EKS cluster.

## Common Verification Commands

Check namespaces:
```bash
kubectl get ns
```

Check services:
```bash
kubectl get svc -A
```

Check pods:
```bash
kubectl get pods -A
```

Check current context:
```bash
kubectl config current-context
```

## Access Flow Summary
```bash
Create IAM Access Key
        ↓
Configure AWS CLI on Server
        ↓
Verify IAM Authentication
        ↓
Update kubeconfig
        ↓
Add EKS Access Entry
        ↓
Verify kubectl access
```

## Troubleshooting

Check:

- AWS credentials are configured correctly
- IAM user exists in EKS Access Entries
- Correct cluster name and region are used
- kubeconfig was updated successfully

