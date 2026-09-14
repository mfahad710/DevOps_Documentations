# AWS CLI Configuration with Multiple Profiles

## Overview

AWS CLI profiles allow us to configure and use multiple AWS accounts, IAM users, roles, or environments from the same machine.

For example, we may have:

- `default`: personal AWS account
- `dev`: development account
- `staging`: staging account
- `prod`: production account
- `learning`: AWS learning account

Instead of repeatedly changing credentials, we can select the required profile with:

```bash
aws <command> --profile <profile-name>
```

## How AWS CLI Stores Configuration

AWS CLI normally stores credentials and configuration in two files:

```text
~/.aws/credentials
~/.aws/config
```

### Credentials file

```text
~/.aws/credentials
```

This normally contains:

- Access key ID
- Secret access key
- Session token, when applicable

Example:

```ini
[default]
aws_access_key_id = AKIAxxxxxxxxxxxxxxxx
aws_secret_access_key = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

[dev]
aws_access_key_id = AKIAyyyyyyyyyyyyyyyy
aws_secret_access_key = yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
```

### Config file

```text
~/.aws/config
```

This normally contains:

- AWS region
- Output format
- Role configuration
- Other AWS CLI settings

Example:

```ini
[default]
region = ap-southeast-1
output = json

[profile dev]
region = ap-southeast-1
output = json
```

> **Important:** The `[profile name]` syntax is used in `~/.aws/config`, while `~/.aws/credentials` uses `[name]`.


## Configure the Default Profile

Run:

```bash
aws configure
```

AWS CLI asks:

```text
AWS Access Key ID [None]:
AWS Secret Access Key [None]:
Default region name [None]:
Default output format [None]:
```

This creates or updates the `default` profile.

Test it:

```bash
aws sts get-caller-identity
```

We can also explicitly specify:

```bash
aws sts get-caller-identity --profile default
```

## Configure a Named Profile

To create another profile:

```bash
aws configure --profile dev
```

Now we have:

```text
default
dev
```

Test the `dev` profile:

```bash
aws sts get-caller-identity --profile dev
```

## Create Multiple Profiles

We can configure as many profiles as required.

For example:

```bash
aws configure --profile dev
aws configure --profile staging
aws configure --profile prod
aws configure --profile learning
```

Check available profiles:

```bash
aws configure list-profiles
```

## Using a Specific Profile

The safest approach is to specify the profile explicitly.

#### Check AWS identity

```bash
aws sts get-caller-identity --profile dev
```

#### List S3 buckets

```bash
aws s3 ls --profile dev
```

#### List EC2 instances

```bash
aws ec2 describe-instances --profile dev
```

#### List RDS instances

```bash
aws rds describe-db-instances --profile dev
```

#### List EKS clusters

```bash
aws eks list-clusters --profile dev
```

This prevents accidentally running commands against another AWS account.


## Using Environment Variables

AWS CLI can use the `AWS_PROFILE` environment variable.

Set it temporarily:

```bash
export AWS_PROFILE=dev
```

Now:

```bash
aws sts get-caller-identity
```

uses the `dev` profile.

We can verify:

```bash
echo $AWS_PROFILE
```

Switch to another profile:

```bash
export AWS_PROFILE=prod
```

Then:

```bash
aws sts get-caller-identity
```

uses `prod`.

Remove the variable:

```bash
unset AWS_PROFILE
```

The CLI then falls back to its normal credential resolution behavior, including the `default` profile when applicable.


## Difference Between `--profile` and `AWS_PROFILE`

#### `--profile`

```bash
aws s3 ls --profile dev
```

Only this command uses `dev`.

### `AWS_PROFILE`

```bash
export AWS_PROFILE=dev
```

Commands in that shell session use `dev` unless another profile is explicitly specified.

## Inspect a Profile

Use:

```bash
aws configure list --profile dev
```

This is useful for troubleshooting.

> Secret access keys are masked in the output.

## Get a Specific Configuration Value

For example, get the region:

```bash
aws configure get region --profile dev
```

Get the output format:

```bash
aws configure get output --profile dev
```

## Configure Region Separately

We can configure a profile's region:

```bash
aws configure set region ap-southeast-1 --profile dev
```

Set output format:

```bash
aws configure set output json --profile dev
```

Verify:

```bash
aws configure get region --profile dev
```

## AWS CLI Configuration Precedence

AWS CLI can obtain credentials and settings from several places.

A simplified credential resolution order includes:

1. Command-line options where applicable
2. Environment variables
3. AWS CLI configuration/profile files
4. IAM role credentials for supported AWS environments
5. Other supported credential providers

For example:

```bash
export AWS_PROFILE=dev
```

can influence which profile is selected.

Explicitly specifying:

```bash
aws s3 ls --profile prod
```

is useful because it clearly identifies the intended profile for that command.


## Using Profiles with Terraform

Terraform can use AWS CLI profiles.

Example provider:

```hcl
provider "aws" {
  region  = "ap-southeast-1"
  profile = "dev"
}
```

Then Terraform uses the `dev` AWS CLI profile.

Alternatively, we can use:

```bash
export AWS_PROFILE=dev
```

and configure Terraform without specifying the profile:

```hcl
provider "aws" {
  region = "ap-southeast-1"
}
```

Before running Terraform, verify:

```bash
aws sts get-caller-identity --profile dev
```

Then:

```bash
terraform init
terraform plan
```

> For production infrastructure, always verify the AWS account before `terraform apply` or destructive operations.


## IAM User Access Keys vs IAM Roles

AWS CLI profiles can be based on different authentication mechanisms.

## Access Keys

Traditional profile:

```ini
[dev]
aws_access_key_id = ...
aws_secret_access_key = ...
```

## IAM Role

A profile can also assume a role.

Example:

```ini
[profile dev-admin]
role_arn = arn:aws:iam::123456789012:role/DevAdminRole
source_profile = default
region = ap-southeast-1
```

Here:

```text
default
   |
   +---- assumes ----> DevAdminRole
```

Use:

```bash
aws sts get-caller-identity --profile dev-admin
```

The resulting identity should show the assumed role.


## MFA with Role-Based Profiles

For environments requiring MFA, role-based profiles can be configured with MFA-related settings.

Example:

```ini
[profile production]
role_arn = arn:aws:iam::123456789012:role/ProductionRole
source_profile = default
mfa_serial = arn:aws:iam::111111111111:mfa/user
region = ap-southeast-1
```

The exact setup depends on the organization's IAM architecture.

Role-based authentication is generally preferable to maintaining long-lived access keys when our organization supports it.

## Security Best Practices
- Never commit AWS credentials
- Prefer IAM Roles and Short-Lived Credentials
- Apply Least Privilege
- Never Share Secret Keys

## Useful Shell Aliases

We can create aliases to make profile switching easier.

For Bash/Zsh:

```bash
alias aws-dev='export AWS_PROFILE=dev'
alias aws-prod='export AWS_PROFILE=prod'
```

Then:

```bash
aws-dev
```

or:

```bash
aws-prod
```

Always verify after switching:

```bash
aws sts get-caller-identity
```
