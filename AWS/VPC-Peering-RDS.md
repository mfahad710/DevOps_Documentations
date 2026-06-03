# AWS VPC Peering
## Aurora RDS Cross-Region Setup Guide

This guide covers setting up VPC Peering between two AWS regions for an Aurora Global Database setup (Primary: `ap-southeast-1`, Secondary: `ap-southeast-2`).


## VPC Peering

VPC Peering is a networking connection between two VPCs that enables them to communicate using **private IP addresses**, as if they were in the same network. Traffic between peered VPCs travels over **AWS's private backbone network** and never touches the public internet.

**Why it is needed for Aurora Global Database:**
When our primary Aurora cluster is in `ap-southeast-1` and secondary is in `ap-southeast-2`, our application server needs network-level access to both regions. After a cross-region failover, the Aurora Global Writer Endpoint automatically updates to point to the new primary, but our app server must be able to **reach that new region** over the network. Without VPC Peering, the connection will fail after failover even though the endpoint updated correctly.


## Architecture Overview

```
ap-southeast-1 (Primary)                ap-southeast-2 (Secondary)
┌──────────────────────────┐             ┌──────────────────────────┐
│   VPC  10.0.0.0/16       │             │   VPC  10.1.0.0/16       │
│                          │             │                          │
│  ┌────────────────────┐  │             │                          │
│  │    App Server      │  │             │                          │
│  └─────────┬──────────┘  │             │                          │
│            │             │             │                          │
│  ┌─────────▼──────────┐  │◄──Peering──►│  ┌────────────────────┐  │
│  │  Aurora Writer     │  │  pcx-xxxx   │  │  Aurora Reader     │  │
│  │ (Primary Cluster)  │  │             │  │ (Secondary Cluster)│  │
│  └────────────────────┘  │             │  └────────────────────┘  │
└──────────────────────────┘             └──────────────────────────┘
  Route: 10.1.0.0/16 → pcx-xxxx          Route: 10.0.0.0/16 → pcx-xxxx
```


## Prerequisites

Before starting, ensure the following:

### 1. Non-overlapping CIDR Blocks

our two VPCs must have **different, non-overlapping CIDR ranges**:

| Region | VPC | CIDR Block |
|--------|-----|------------|
| ap-southeast-1 (Primary) | fort-stg-vpc-primary | `10.0.0.0/16` |
| ap-southeast-2 (Secondary) | fort-stg-vpc-secondary | `10.1.0.0/16` |

> **Important:** If our CIDRs overlap (e.g. both are `10.0.0.0/16`), VPC Peering is not possible. You would need to re-IP one of the VPCs or use AWS Transit Gateway instead.

### 2. Collect Required Information

Note these down before starting:

```
Primary Region VPC ID      →  vpc-xxxxxxxxxx   (ap-southeast-1)
Secondary Region VPC ID    →  vpc-yyyyyyyyyy   (ap-southeast-2)
Primary VPC CIDR           →  10.0.0.0/16
Secondary VPC CIDR         →  10.1.0.0/16
Aurora Subnet Route Table  →  rtb-xxxxxxxxxx   (in each region)
Aurora Security Group ID   →  sg-xxxxxxxxxx    (in each region)
```

### 3. IAM Permissions

Ensure our AWS user/role has the following permissions:

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:CreateVpcPeeringConnection",
    "ec2:AcceptVpcPeeringConnection",
    "ec2:CreateRoute",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:ModifyVpcPeeringConnectionOptions"
  ],
  "Resource": "*"
}
```

## Step 1: Create Peering Connection (Primary Region)

1. Open **AWS Console** and switch to **`ap-southeast-1`** (Primary Region)
2. Navigate to **VPC → Peering Connections**
3. Click **Create Peering Connection**
4. Fill in the form:

```
Name tag                →  fort-stg-vpc-peering
VPC ID (Requester)      →  vpc-xxxxxxxxxx   (our primary VPC)
Account                 →  ● My Account
Region                  →  ● Another Region → ap-southeast-2
VPC ID (Accepter)       →  vpc-yyyyyyyyyy   (our secondary VPC ID)
```

5. Click **Create Peering Connection**
6. Note down the **Peering Connection ID**: `pcx-xxxxxxxxxx`

> Status will show **Pending Acceptance** until the other side accepts.

## Step 2: Accept Peering Connection (Secondary Region)

1. Switch AWS Console to **`ap-southeast-2`** (Secondary Region)
2. Navigate to **VPC → Peering Connections**
3. We will see the connection with status **Pending Acceptance**
4. Select it → click **Actions → Accept Request**
5. Confirm the dialog → click **Accept Request**

Status will change to **Active**

## Step 3: Update Route Tables (Primary Region)

This tells the primary VPC to route traffic destined for the secondary VPC through the peering connection.

1. Stay in **`ap-southeast-1`**
2. Navigate to **VPC → Route Tables**
3. Find and select the **route table attached to our Aurora DB subnet**
4. Click **Routes tab → Edit Routes → Add Route**

```
Destination   →   10.1.0.0/16        (secondary VPC CIDR)
Target        →   pcx-xxxxxxxxxx     (peering connection ID)
```

5. Click **Save Changes**

> If we have multiple private subnet route tables, add this route to **each one**.

## Step 4: Update Route Tables (Secondary Region)

This tells the secondary VPC to route traffic destined for the primary VPC through the peering connection.

1. Switch to **`ap-southeast-2`**
2. Navigate to **VPC → Route Tables**
3. Find and select the **route table attached to our secondary Aurora subnet**
4. Click **Routes tab → Edit Routes → Add Route**

```
Destination   →   10.0.0.0/16        (primary VPC CIDR)
Target        →   pcx-xxxxxxxxxx     (same peering connection ID)
```

5. Click **Save Changes**

## Step 5: Update Security Groups

Both Aurora clusters must allow **inbound PostgreSQL traffic** from the other VPC's CIDR range.

### Primary Region Aurora Security Group (`ap-southeast-1`)

1. Navigate to **EC2 → Security Groups**
2. Find the security group attached to our **primary Aurora cluster**
3. Click **Inbound Rules → Edit Inbound Rules → Add Rule**

```
Type          →   PostgreSQL
Protocol      →   TCP
Port Range    →   5432
Source        →   10.1.0.0/16
Description   →   Allow PostgreSQL from secondary region VPC (ap-southeast-2)
```

4. Click **Save Rules**

### Secondary Region Aurora Security Group (`ap-southeast-2`)

1. Switch to **`ap-southeast-2`**
2. Navigate to **EC2 → Security Groups**
3. Find the security group attached to our **secondary Aurora cluster**
4. Click **Inbound Rules → Edit Inbound Rules → Add Rule**

```
Type          →   PostgreSQL
Protocol      →   TCP
Port Range    →   5432
Source        →   10.0.0.0/16
Description   →   Allow PostgreSQL from primary region VPC (ap-southeast-1)
```

5. Click **Save Rules**

## Step 6: Enable DNS Resolution

Without this step, Aurora **private DNS hostnames** (e.g. `*.rds.amazonaws.com`) will not resolve correctly across the peering connection and our connections will fail.

1. Navigate to **VPC → Peering Connections** (either region)
2. Select our peering connection `pcx-xxxxxxxxxx`
3. Click **Actions → Edit DNS Settings**
4. Enable both options:

```
✅  Allow DNS resolution from accepter VPC to requester VPC
✅  Allow DNS resolution from requester VPC to accepter VPC
```

5. Click **Save**


## Important Limitations

| Limitation | Details |
|---|---|
| **No transitive routing** | Traffic cannot flow through a VPC to reach a third VPC via peering |
| **No overlapping CIDRs** | VPC CIDRs must be completely non-overlapping |
| **No security group cross-reference** | We cannot reference security groups from the other region, use CIDR ranges instead |
| **Data transfer cost** | Cross-region peering traffic is charged at standard inter-region data transfer rates |
| **Point-to-point only** | Each peering connection connects exactly two VPCs |

> For more than 2 VPCs or complex hub-and-spoke topologies, consider **AWS Transit Gateway** instead of VPC Peering.

