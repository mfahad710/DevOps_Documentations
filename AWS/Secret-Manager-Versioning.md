# AWS Secrets Manager Versioning

## Purpose

AWS Secrets Manager automatically manages `AWSCURRENT` / `AWSPREVIOUS` staging labels, but only retains one step of history by default. This solution adds an automated **custom labeling layer** on top of that, giving every secret update a permanent, sequential, human-readable version marker (`v-1`, `v-2`, `v-3`, ...) for audit tracking and manual rollback, without touching how `AWSCURRENT`/`AWSPREVIOUS` already work.

## Architecture

```
Secret value changes (PutSecretValue / UpdateSecret)
        │
        ▼
   AWS CloudTrail  (captures the API call as a management event, on by default, no trail required)
        │
        ▼
  Amazon EventBridge rule  (matches on eventSource + eventName, invokes Lambda)
        │
        ▼
   AWS Lambda function  (finds AWSCURRENT version → attaches next sequential custom label → prunes oldest if near the cap)
        │
        ▼
  Secret now has both AWSCURRENT and a permanent v-N label on the same version
```

**Why CloudTrail is in the middle:** Secrets Manager does not emit events to `EventBridge` natively, every API call is logged by CloudTrail as a management event, and `EventBridge` rules match against those CloudTrail log entries. `PutSecretValue` and `UpdateSecret` are captured by an account's default CloudTrail activity automatically.

## EventBridge
EventBridge is a serverless service that uses events to connect application components together, making it easier for you to build scalable event-driven applications. 
EventBridge provides simple and consistent ways to ingest, filter, transform, and deliver events so you can build applications quickly.

**Event Buses** are routers that receive events and delivers them to zero or more targets.
**Event buses** are well-suited for routing events from many sources to many targets, with optional transformation of events prior to delivery to a target.

### Setting Up EventBridge for AWS Secrets Manager Versioning
**Goal:** Trigger a Lambda function automatically whenever a secret's value is updated, so the Lambda can attach a custom staging label (e.g. an incrementing `v-N`) to the version that just became `AWSCURRENT`, for audit and rollback tracking.

**Important:** Secrets Manager does not send events to EventBridge natively. Every API call is logged by CloudTrail, and EventBridge matches on those CloudTrail log entries. `PutSecretValue`, `UpdateSecret` are captured by an account's default CloudTrail activity automatically, no trail needs to be manually created for this to work.

#### Step 1: Create the EventBridge rule
- Console → **Amazon EventBridge** → **Rules** (under Buses) → **confirm Event bus: default** → **Create rule**.
- Builder mode: uses Enhanced builder.
  - Fill in:
    - Name: `dev-secrets-versioning-EBrule`
    - Description: Triggers Lambda Function to attach custom version label when secrets are updated.
    - Event bus: default
- Building the event pattern
  - **Secrets Manager** has no pre-built card in the Enhanced builder's event catalog (its events flow through CloudTrail, not a native partner source).  
  Instead, click directly into the `Event pattern` (filter) box paste the pattern in as JSON:

```json
{
  "source": ["aws.secretsmanager"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["secretsmanager.amazonaws.com"],
    "eventName": ["PutSecretValue", "UpdateSecret"]
  }
}
```

#### Step 2: Wire the Lambda as the target
- Click the **Targets tab**
- Target type: **AWS service**
- Select a target: Lambda function
- Function: `dev-secret-manager-versioning-lambda`
- Create.

The console automatically adds the resource-based permission that lets EventBridge invoke this Lambda, no manual lambda add-permission step needed (unlike the CLI path).

Role Created: `Amazon_EventBridge_Invoke_Lambda_100143870`


Notes on what was deliberately excluded and why:
- **No `RotationSucceeded`**: We doesn't use Secrets Manager's native rotation, so the `$or` needed to also match Service Events (as opposed to API Call events) was removed for a simpler, single-branch pattern.
- **`UpdateSecret` is intentionally kept**, even though it doesn't always create a new version (e.g. a metadata-only change like description or KMS key). Some IaC tooling (Terraform/CloudFormation) can update secret *values* via `UpdateSecret` rather than `PutSecretValue`, dropping it risks silently missing real version changes. The Lambda's idempotency check (Section 4) absorbs the no-op case where `UpdateSecret` fires without a real version change.

**Target:** Lambda function `dev-secrets-manager-versioning-lambda`, invoked via a resource-based permission on the function (auto-added when the target is set through the console) and an EventBridge-generated IAM role (`Amazon_EventBridge_Invoke_Lambda_<id>`) used to authorize the invoke call.

## Lambda Function
**Goal:** A Lambda function, invoked by the EventBridge rule `dev-secret-manager-versioning-EBrule`, that attaches a custom staging label (e.g. `v-N`) to whichever version currently holds `AWSCURRENT`, whenever a secret's value changes (`PutSecretValue` or `UpdateSecret`). 

`AWSCURRENT` itself is applied automatically by Secrets Manager on every write, this function only manages the custom label layer on top of it.

#### Step 1: Create the function
- Console → **Lambda** → **Create function**
- Author from scratch
- Function name: `dev-secret-manager-versioning-lambda`
- Runtime: **Python 3.13**
- Create function

#### Step 2: Add Secrets Manager permissions to the execution role
The auto-created role only has `AWSLambdaBasicExecutionRole` (CloudWatch Logs only). It has zero access to Secrets Manager, which the function needs for its actual job.

- Lambda Function page → **Configuration tab** → **Permissions** → click the **execution role** (`dev-secret-manager-versioning-role-442ki0hk`) link (opens IAM in a new tab)
- On the role **IAM page** → **Permissions tab**
  - Add **permissions** → **Create inline policy** → **JSON tab** → paste:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:UpdateSecretVersionStage",
      "secretsmanager:DescribeSecret"
    ],
    "Resource": "*"
  }]
}
```

- Next → name it `dev-secret-manager-versioning-policy-442ki0hk` → **Create policy**

#### Step 3: Function code
```python
import re
import boto3
from botocore.exceptions import ClientError

secretsmanager = boto3.client("secretsmanager")

LABEL_PATTERN = re.compile(r"^v-(\d+)$")
CUSTOM_LABEL_SOFT_CAP = 15   # prune oldest custom label at this count (hard AWS limit is 20 total per secret)


def lambda_handler(event, context):
    secret_arn = event.get("detail", {}).get("responseElements", {}).get("arn")
    event_name = event.get("detail", {}).get("eventName", "unknown")

    if not secret_arn:
        print(f"No secret ARN in event (eventName={event_name}); nothing to do.")
        return {"statusCode": 200, "body": "no-op: missing secret ARN"}

    print(f"Processing {event_name} for {secret_arn}")

    versions = list_versions(secret_arn)
    current_version_id, current_stages = find_current_version(versions)

    if current_version_id is None:
        print("No AWSCURRENT version found; skipping.")
        return {"statusCode": 200, "body": "no-op: no AWSCURRENT found"}

    # Idempotency: if this version already has a sequential label, it was
    # already processed (e.g. a metadata-only UpdateSecret re-fired the rule
    # without creating a new version) — skip rather than double-labeling.
    if any(LABEL_PATTERN.match(s) for s in current_stages):
        print(f"{current_version_id} already has a sequential label; no action needed.")
        return {"statusCode": 200, "body": "no-op: already labeled"}

    next_n = get_next_label_number(versions)
    new_label = f"v-{next_n}"

    prune_if_needed(secret_arn, versions)
    attach_label(secret_arn, new_label, current_version_id)

    return {"statusCode": 200, "body": f"labeled {current_version_id} with {new_label}"}


def list_versions(secret_arn):
    versions = []
    kwargs = {"SecretId": secret_arn, "IncludeDeprecated": False}
    while True:
        resp = secretsmanager.list_secret_version_ids(**kwargs)
        versions.extend(resp.get("Versions", []))
        next_token = resp.get("NextToken")
        if not next_token:
            break
        kwargs["NextToken"] = next_token
    return versions


def find_current_version(versions):
    for v in versions:
        if "AWSCURRENT" in v.get("VersionStages", []):
            return v["VersionId"], v["VersionStages"]
    return None, []


def get_next_label_number(versions):
    max_n = 0
    for v in versions:
        for stage in v.get("VersionStages", []):
            m = LABEL_PATTERN.match(stage)
            if m:
                max_n = max(max_n, int(m.group(1)))
    return max_n + 1


def prune_if_needed(secret_arn, versions):
    custom_labels = []
    for v in versions:
        for stage in v.get("VersionStages", []):
            m = LABEL_PATTERN.match(stage)
            if m:
                custom_labels.append((int(m.group(1)), v["VersionId"]))

    if len(custom_labels) < CUSTOM_LABEL_SOFT_CAP:
        return

    # sort numerically (not lexicographically — "v-10" < "v-2" as strings, which is wrong)
    custom_labels.sort(key=lambda x: x[0])
    oldest_n, oldest_version_id = custom_labels[0]
    oldest_label = f"v-{oldest_n}"

    print(f"At {len(custom_labels)} custom labels; pruning oldest: {oldest_label} from {oldest_version_id}")
    try:
        secretsmanager.update_secret_version_stage(
            SecretId=secret_arn,
            VersionStage=oldest_label,
            RemoveFromVersionId=oldest_version_id,
        )
    except ClientError as e:
        print(f"Failed to prune {oldest_label}: {e}")


def attach_label(secret_arn, label, target_version_id):
    secretsmanager.update_secret_version_stage(
        SecretId=secret_arn,
        VersionStage=label,
        MoveToVersionId=target_version_id,
    )
    print(f"Attached {label} to {target_version_id}")
```

#### Step 4: Wire it as the EventBridge target
EventBridge Rule (`dev-secret-manager-versioning-EBrule`) → **Targets tab** → set **target function** to `dev-secret-manager-versioning-lambda` → Update

> *Notes*  
> **Labeling scheme:** sequential, never reused — `v-1`, `v-2`, `v-3`, ... `v-N`.  
> **Custom label cap:** Secrets Manager hard-caps staging labels at **20 per secret**, shared across all versions (`AWSCURRENT`/`AWSPENDING`/`AWSPREVIOUS` count toward this). The Lambda prunes the oldest custom label once the count reaches a soft cap of **15**, leaving headroom under the hard limit. Pruned numbers are never reused — if `v-1` is pruned, the next new label is still the true running max + 1, not `v-1` again.

## Rollback Procedure

Move `AWSCURRENT` back to the version holding an earlier label:

```bash
aws secretsmanager update-secret-version-stage \
  --secret-id dev/ssh-keys \
  --version-stage AWSCURRENT \
  --move-to-version-id <VersionId of the older v-N label> \
  --remove-from-version-id <current AWSCURRENT VersionId>
```

The old (bad) version isn't deleted, it's demoted, and its own `v-N` label stays intact for reference.
