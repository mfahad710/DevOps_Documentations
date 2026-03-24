# Release Pipeline - Package Registry

The Document explains the workflow, stages, and job functions of the automated Production Release Pipeline in GitLab.

Pipeline fully automates:
- Creating Auto-tag
- Creating GitLab Releases
- Attaching artifacts (JARs) to Release Notes
- Sending email notifications

The pipeline runs only when triggered on the branch and via manual or web trigger.

## `.gitlab-ci.yml` file

```bash
workflow:
  name: Release Pipeline
  rules:
    - if: '$CI_COMMIT_REF_NAME == "<Branch_Name>" && ($CI_PIPELINE_SOURCE == "manual" || $CI_PIPELINE_SOURCE == "web")'

stages:
  - release_note
  - notify

# =====================
# Release_Note Stage (Auto Tagging)
# =====================
Create_Auto_Tag:
  stage: release_note
  tags:
    - <Runner_Tag>
  
  # Don't pull artifacts from Previous Jobs
  dependencies: []

  # This Job only talks to GitLab API so "none" uses to Prevent Pulling Project Repo Files or Git history
  variables:
    GIT_STRATEGY: none

  script:
    - |
      echo "Fetching existing tags... (Fetch all tags exist on the Repo)"
      TAGS_JSON=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" \
        "http://<GitLab_Server_IP>/api/v4/projects/${CI_PROJECT_ID}/repository/tags")

      # --- Extract latest tag (newest first) ---
      LATEST_TAG=$(echo "$TAGS_JSON" | jq -r '.[] | select(.name) | .name' | head -n1)

      if [ "$LATEST_TAG" = "null" ] || [ -z "$LATEST_TAG" ]; then
        echo "No existing tags found. Starting from 0.0.1"
        LATEST_TAG="0.0.1"
      fi
      echo "Latest tag found: $LATEST_TAG"

      # --- Parse version numbers ---
      BASE="${LATEST_TAG#v}"  # Remove leading 'v' if present
      IFS='.' read -r major minor patch <<< "$BASE"
      patch=$((patch + 1))
      NEW_TAG="${major}.${minor}.${patch}"
      echo "New tag to be created: ${NEW_TAG}"

      # --- Create new tag ---
      REF=${REF:-$CI_COMMIT_SHA}
      MESSAGE="Automated tag from ${LATEST_TAG} to ${NEW_TAG}"

      echo "Creating tag ${NEW_TAG} from ref ${REF}"
      curl --fail --show-error --silent --request POST \
        --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" \
        --form "tag_name=${NEW_TAG}" \
        --form "ref=${REF}" \
        --form "message=${MESSAGE}" \
        "http://<GitLab_Server_IP>/api/v4/projects/${CI_PROJECT_ID}/repository/tags"

      echo "Tag '${NEW_TAG}' created successfully via API."

# =====================
# Release_Note Stage (Create Release Notes)
# =====================
Create_Release:
  stage: release_note
  tags:
    - <Runner_Tag>

  # Don't pull artifacts from Previous Jobs
  dependencies: []
  
  # This Job Depends on the "Create_Auto_Tag" Job, Run after it
  needs:
    - Create_Auto_Tag

  script:
  - |
    echo "Fetching latest two tags..."
    TAGS_JSON=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" \
      "http://<GitLab_Server_IP>/api/v4/projects/${CI_PROJECT_ID}/repository/tags")

    # --- Select the most recent tag as LATEST_TAG and the one before it as PREV_TAG ---
    LATEST_TAG=$(echo "$TAGS_JSON" | jq -r '.[] | select(.name) | .name' | head -n1)
    PREV_TAG=$(echo "$TAGS_JSON" | jq -r '.[] | select(.name) | .name' | sed -n '2p')

    if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
      echo "Error: No tags found. Please create a tag first."
      exit 1
    fi

    echo "Latest tag: $LATEST_TAG"
    echo "Previous tag: $PREV_TAG"

    echo "Collecting commits between ${PREV_TAG:-initial commit} and ${LATEST_TAG}..."
    if [ -z "$PREV_TAG" ] || [ "$PREV_TAG" = "null" ]; then
      COMMITS=$(git log --pretty=format:"- %s (%h)" $LATEST_TAG)
    else
      COMMITS=$(git log --pretty=format:"- %s (%h)" ${PREV_TAG}..${LATEST_TAG})
    fi

    [ -z "$COMMITS" ] && COMMITS="No new commits since previous release."

    echo "New commits found:"
    echo "$COMMITS"

    RELEASE_TITLE="Release ${LATEST_TAG}"
    ESCAPED_DESC=$(printf '%s\n' "Changes included in this release:" "$COMMITS" | jq -sRr @json)

    echo "Creating release '${RELEASE_TITLE}' for tag '${LATEST_TAG}'..."

    CREATE_STATUS=$(curl --silent --output /dev/stderr --write-out "%{http_code}" \
      --request POST \
      --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" \
      --header "Content-Type: application/json" \
      --data "{\"name\": \"${RELEASE_TITLE}\", \"tag_name\": \"${LATEST_TAG}\", \"description\": ${ESCAPED_DESC}}" \
      "http://<GitLab_Server_IP>/api/v4/projects/${CI_PROJECT_ID}/releases" || true)

    if [ "$CREATE_STATUS" = "400" ] || [ "$CREATE_STATUS" = "409" ]; then
      echo "Release may already exist — retrying with PUT..."
      curl --fail --show-error --silent --request PUT \
        --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" \
        --header "Content-Type: application/json" \
        --data "{\"description\": ${ESCAPED_DESC}}" \
        "http://<GitLab_Server_IP>/api/v4/projects/${CI_PROJECT_ID}/releases/${LATEST_TAG}"
    fi

    echo "Release '${RELEASE_TITLE}' created or updated successfully."

# =====================
# Release_Note Stage (Attach JAR to Release Note)
# =====================
Attach_JAR_To_Release:
  stage: release_note
  tags:
    - <Runner_Tag>
  
  # Don't pull artifacts from Previous Jobs
  dependencies: []
  
  needs:
    - Create_Release

  script:
  - |
    echo "Fetching latest tag..."
    LATEST_TAG=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" \
      "http://<GitLab_Server_IP>/api/v4/projects/${CI_PROJECT_ID}/repository/tags" | \
      jq -r '.[] | select(.name) | .name' | head -n1)

    echo "Attaching JAR to release for tag ${LATEST_TAG}..."

    # --- Attach JAR to the existing release ---

    echo "Searching for JAR file..."
    JAR_FILE=$(ls target/*.jar 2>/dev/null | head -n1)

    if [ -z "$JAR_FILE" ]; then
      echo "ERROR: No JAR file found in target directory."
      exit 1
    fi

    # Rename JAR_FILE name
      NEW_JAR_FILE="Release-${LATEST_TAG}.jar"
      mv "$JAR_FILE" "target/${NEW_JAR_FILE}"
      JAR_FILE="target/${NEW_JAR_FILE}"

    echo "JAR found: $JAR_FILE"

    echo "Publishing to Package Registry..."

    PACKAGE_NAME="<Package_Registry_Name>"
    PACKAGE_VERSION="${LATEST_TAG}"
    FILE_NAME=$(basename "$JAR_FILE")

    UPLOAD_RESPONSE=$(curl --silent --request PUT \
      --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" \
      --upload-file "${JAR_FILE}" \
      "http://<GitLab_Server_IP>/api/v4/projects/${CI_PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${PACKAGE_VERSION}/${FILE_NAME}" \
      || { echo "Package upload failed"; exit 1; })

    echo "Upload response: $UPLOAD_RESPONSE"

    PACKAGE_URL="http://<GitLab_Server_IP>/api/v4/projects/${CI_PROJECT_ID}/packages/generic/${PACKAGE_NAME}/${PACKAGE_VERSION}/${FILE_NAME}"

    echo "Attaching package URL to release..."

    curl --fail --show-error --silent --request POST \
      --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" \
      --data "name=${FILE_NAME}&url=${PACKAGE_URL}" \
      "http://<GitLab_Server_IP>/api/v4/projects/${CI_PROJECT_ID}/releases/${LATEST_TAG}/assets/links"

    echo "JAR attached successfully to release ${LATEST_TAG}."

# =====================
# Notify Stage (Send Release Note to DevOps)
# =====================
send_release_note:
  stage: notify

  tags:
    - <Runner_Tag>
 
  # No need to download artifacts from earlier jobs
  dependencies: []

  variables:
    GIT_STRATEGY: none
  
  needs:
    - Attach_JAR_To_Release  # Waits for the release to be created and JAR attached before sending notification

  script:
    - echo "============================================================"
    - echo "Sending Release Note Email to DevOps..."
    - echo "============================================================"
    - |
      # Fetch latest tag via GitLab API
      LATEST_TAG=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" \
        "http://<GitLab_Server_IP>/api/v4/projects/${CI_PROJECT_ID}/repository/tags" | \
        jq -r '.[] | select(.name) | .name' | head -n1)

      RELEASE_URL="${CI_PROJECT_URL}/-/releases/${LATEST_TAG}"
      EMAIL_BODY="Please find attached the Release (${RELEASE_URL}), kindly update your Environment with the following updated JAR.
      Release Tag: ${LATEST_TAG}
      Pipeline ID: ${CI_PIPELINE_ID}
      Project: ${CI_PROJECT_NAME}
      
      Thanks,
      DevOps Team"

      # Using curl for better compatibility in CI environments
      curl --url "smtp://smtp.office365.com:587" \
        --mail-from "test.watcher@fort.com" \
        --mail-rcpt "fahad@fort.com" \
        --mail-rcpt "fort-notify@fort.com" \
        --user "test.watcher@fort.com:<Mail_Pass>" \
        --ssl-reqd \
        --upload-file - << EOF
      From: test.watcher@fort.com
      To: fahad@fort.com
      Cc: fort-notify@fort.com
      Subject: New Release - ${LATEST_TAG}

      ${EMAIL_BODY}
      EOF

      echo "Release Email sent successfully to DevOps!"
```

> Add the defined variables in the GitLab Variables.