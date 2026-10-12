# AWS Secrets Manager Version Label Replacement

## Overview

This guide identifies AWS Secrets Manager secrets that have version staging labels in the format `v-n` (for example, `v-1`, `v-2`, or `v-12`) and updates selected labels to the format `vn` (for example, `v1`, `v2`, or `v12`).

The workflow has two parts:

1. **Find Versions** — scan secrets and report any staging labels matching `v-<number>`.
2. **Replace Versions** — update the labels for a specified list of secrets.

> **Important:** A staging label is metadata attached to a secret version; this procedure changes labels, not the secret value itself. Review the dry-run output and confirm the intended secret names and labels before making changes.

## Prerequisites

Make sure the environment has:

- AWS CLI installed and configured with credentials for the correct AWS account and region.
- `jq` installed to parse the JSON returned by AWS CLI.
- Permission to list secrets and their version IDs/staging labels.
- For the replacement step, permission to call `secretsmanager:UpdateSecretVersionStage`.

Check the active AWS identity and region before running the commands:

```bash
aws sts get-caller-identity
aws configure get region
```

If your environment selects the region through a profile or environment variable, verify that setting too. Run the commands against the intended account and region.

## 1. Find versions with labels in `v-n` format

The following command scans secret names returned by Secrets Manager and prints any staging labels matching `v-<number>`.

```bash
aws secretsmanager list-secrets --query "SecretList[].Name" --output text | tr '\t' '\n' | while read -r secret; do
  match=$(aws secretsmanager list-secret-version-ids --secret-id "$secret" \
    --query "Versions[].VersionStages" --output json 2>/dev/null \
    | jq -r '.[] | .[] | select(test("^v-[0-9]+$"))')
  if [ -n "$match" ]; then
    echo "=== $secret ==="
    echo "$match" | sort -u
  fi
done
```

### How it works

- `list-secrets` retrieves the secret names visible to the configured AWS identity.
- `tr '\t' '\n'` puts the tab-separated names on separate lines.
- The loop processes each secret name.
- `list-secret-version-ids` retrieves version information and staging labels for that secret.
- `jq` keeps only labels matching the regular expression `^v-[0-9]+$`:
  - `^` means the start of the label.
  - `v-` matches the literal characters `v-`.
  - `[0-9]+` matches one or more digits.
  - `$` means the end of the label.
- `sort -u` sorts the matching labels and removes duplicates.
- Secrets without matching labels are not printed.

### Example output

```text
=== eks/preprod/community-service-secrets ===
v-1
v-2
v-3
=== eks/preprod/payment-service-secrets ===
v-4
```

The example is illustrative; actual output depends on the secrets and labels in your account.

**Note:** Errors from `list-secret-version-ids` are redirected to `/dev/null` in this scan, so access or lookup errors may not be displayed. If you expect a secret to appear but it does not, test the AWS CLI command for that secret directly and check the account, region, and permissions.

## 2. Replace labels from `v-n` to `vn`

The script below targets only the secrets listed in the `SECRETS` array. It starts in **dry-run mode**, which prints the changes it would make without modifying AWS.

```bash
#!/usr/bin/env bash

DRY_RUN=true   # set to false only after reviewing the dry-run output

SECRETS=(
  "eks/preprod/community-service-secrets"
  "eks/preprod/payment-service-secrets"
)

for secret in "${SECRETS[@]}"; do
  aws secretsmanager list-secret-version-ids --secret-id "$secret" --output json \
    | jq -r '.Versions[] | .VersionId as $vid | .VersionStages[] | select(test("^v-[0-9]+$")) | "\($vid) \(.)"' \
    | while read -r version_id old_label; do
        new_label="${old_label/v-/v}"   # v-3 -> v3

        if [ "$DRY_RUN" = true ]; then
          echo "[DRY RUN] $secret: would move $old_label -> $new_label on $version_id"
          continue
        fi

        echo "$secret: migrating $old_label -> $new_label on $version_id"

        aws secretsmanager update-secret-version-stage \
          --secret-id "$secret" \
          --version-stage "$new_label" \
          --move-to-version-id "$version_id"

        aws secretsmanager update-secret-version-stage \
          --secret-id "$secret" \
          --version-stage "$old_label" \
          --remove-from-version-id "$version_id"
      done
done
```

### Configure the target secrets

Edit the `SECRETS` array so it contains the exact secret names you want to update. The script does not automatically modify every secret found in Step 1; it processes only the names in this array.

### How the replacement works

1. `list-secret-version-ids` obtains version IDs and their staging labels for each selected secret.
2. `jq` emits each version ID paired with a label that matches `v-<number>`.
3. `${old_label/v-/v}` replaces the first `v-` with `v`; for example, `v-3` becomes `v3`.
4. With `DRY_RUN=true`, the script prints the proposed change and skips the update commands.
5. With `DRY_RUN=false`, the script:
   - Adds/moves the new label (such as `v3`) to the selected version using `--move-to-version-id`.
   - Removes the old label (such as `v-3`) from that version using `--remove-from-version-id`.

The secret value and version ID are not intentionally changed by these operations; the staging-label assignments are changed.

## 3. Run safely

1. Confirm the AWS account, region, and credentials.
2. Run Step 1 and review the labels it finds.
3. Update the `SECRETS` array with the intended secret names.
4. Keep `DRY_RUN=true` and run the script. Check every proposed label change.
5. If the output is correct and you are authorized to proceed, change `DRY_RUN=true` to `DRY_RUN=false` and run it again.
6. Review the command output and verify the labels afterward.

Do not switch off dry-run mode until the target list and proposed changes have been reviewed. For production secrets, follow your team's change-management and rollback procedures.

## 4. Verify the result

For each modified secret, run:

```bash
aws secretsmanager list-secret-version-ids \
  --secret-id "eks/preprod/community-service-secrets" \
  --query "Versions[].{VersionId:VersionId,VersionStages:VersionStages}" \
  --output table
```

Replace the example secret name with each secret you updated. Confirm that the expected `vn` labels exist and the corresponding `v-n` labels have been removed.

## Notes and limitations

- The matching pattern is deliberately limited to labels such as `v-1` and `v-12`. It does not match `v1`, `v-`, `v-abc`, or labels with extra characters.
- The script only targets the two example secrets until you edit the `SECRETS` array.
- The script does not include explicit error handling. If an AWS CLI update fails, inspect the error and verify the current label assignments before retrying.
- If a destination label such as `v3` already exists on another version, the update may move that label. Check for existing destination labels before executing changes, especially if labels are used by applications or deployment processes.
- AWS Secrets Manager uses staging labels to identify versions. Changing a label may affect systems that refer to that label, so coordinate the change with any dependent applications or automation.