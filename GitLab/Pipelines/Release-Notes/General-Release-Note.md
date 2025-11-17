# Release Pipeline

The Document explains the workflow, stages, and job functions of the automated Production Release Pipeline in GitLab.

Pipeline fully automates:
- Building JARs
- Auto-tag bumping
- Creating GitLab Releases
- Attaching artifacts (JARs) to Release Notes
- Developer approval workflow
- Sending email notifications

The pipeline runs only when triggered on the branch and via manual or web trigger.

## `.gitlab-ci.yml` file

```bash
workflow:
  name: Release Pipeline
  rules:
    - if: '$CI_COMMIT_REF_NAME == "<Branch_Name>" && ($CI_PIPELINE_SOURCE == "manual" || $CI_PIPELINE_SOURCE == "web")'

stages:
  - build
  - release_note
  - approval
  - notify

# -------- Build Stage --------
Build_Jar:
 stage: build
 tags:
   - <Runner_Tag>
 image: maven-jdk17
 script:
   - echo "--------------Building the Code--------------"
   - mvn clean install -DskipTests
 artifacts:
   paths:
     - challenge-services/target/challenge-services-*.jar
   when: on_success
   expire_in: 1 week

# -------- Release Note Stage (Auto Tagging) --------
Create_Auto_Tag:
  stage: release_note
  tags:
    - <Runner_Tag>
  # Don't pull artifacts from Previous Jobs
  dependencies: []
  variables:
    GIT_STRATEGY: none
  script:
    - |
      echo "Fetching existing tags..."
      TAGS_JSON=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" "http://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/repository/tags")

      # --- Extract latest tag (newest first) ---
      LATEST_TAG=$(echo "$TAGS_JSON" | jq -r '.[0].name')
      if [ "$LATEST_TAG" = "null" ] || [ -z "$LATEST_TAG" ]; then
        echo "No existing tags found. Starting from v1.0.0"
        LATEST_TAG="v1.0.0"
      fi
      echo "Latest tag found: $LATEST_TAG"

      # --- Parse version numbers ---
      BASE="${LATEST_TAG#v}"
      IFS='.' read -r major minor patch <<< "$BASE"
      patch=$((patch + 1))
      NEW_TAG="v${major}.${minor}.${patch}"
      echo "New tag to be created: ${NEW_TAG}"

      # --- Create new tag ---
      REF=${REF:-$CI_COMMIT_SHA}
      MESSAGE="Automated tag bump from ${LATEST_TAG} to ${NEW_TAG}"

      echo "Creating tag ${NEW_TAG} from ref ${REF}"
      curl --fail --show-error --silent --request POST --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" --form "tag_name=${NEW_TAG}" --form "ref=${REF}" --form "message=${MESSAGE}" "http://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/repository/tags"

      echo "Tag '${NEW_TAG}' created successfully via API."

# -------- Release Note Stage (Create Release Notes) --------
Create_Release:
  stage: release_note
  tags:
    - <Runner_Tag>
  dependencies: []
  variables:
    GIT_STRATEGY: fetch
  needs:
    - Create_Auto_Tag
  script:
  - |
    echo "Fetching latest two tags..."
    TAGS_JSON=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" "http://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/repository/tags")

    LATEST_TAG=$(echo "$TAGS_JSON" | jq -r '.[0].name')
    PREV_TAG=$(echo "$TAGS_JSON" | jq -r '.[1].name')

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

    CREATE_STATUS=$(curl --silent --output /dev/stderr --write-out "%{http_code}" --request POST --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" --header "Content-Type: application/json" --data "{\"name\": \"${RELEASE_TITLE}\", \"tag_name\": \"${LATEST_TAG}\", \"description\": ${ESCAPED_DESC}}" "http://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/releases" || true)

    if [ "$CREATE_STATUS" = "400" ] || [ "$CREATE_STATUS" = "409" ]; then
      echo "Release may already exist — retrying with PUT..."
      curl --fail --show-error --silent --request PUT --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" --header "Content-Type: application/json" --data "{\"description\": ${ESCAPED_DESC}}" "http://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/releases/${LATEST_TAG}"
    fi

    echo "Release '${RELEASE_TITLE}' created or updated successfully."

# -------- Release Note Stage (Attach JARS to Release Note) --------
Attach_JARs_To_Release:
  stage: release_note
  tags:
    - <RUnner_Tag>
  dependencies: []
  variables:
    GIT_STRATEGY: none
  needs:
    - Create_Release
  script:
  - |
    echo "Fetching latest tag..."
    LATEST_TAG=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" "http://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/repository/tags" | jq -r '.[0].name')

    echo "Attaching JARs to release for tag ${LATEST_TAG}..."

    # --- Find latest successful Build_Jar job ID ---
    echo "Finding successful Build_Jar job..."
    BUILD_JOB_ID=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" "http://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/pipelines/${CI_PIPELINE_ID}/jobs" | jq -r '.[] | select(.name=="Build_Jar") | .id')

    if [ -z "$BUILD_JOB_ID" ]; then
      echo "No Build_Jar job ID found for this pipeline!"
      exit 1
    fi

    echo "Found Build_Jar job ID: $BUILD_JOB_ID"

    # --- Correct Artifact URLs ---
    CHALLENGE_URL="${CI_PROJECT_URL}/-/jobs/${BUILD_JOB_ID}/artifacts/file/challenge-services/target/challenge-services-*.jar"

    echo "Verifying artifact URLs..."
    echo "$CHALLENGE_URL"

    # --- Attach each JAR to the existing release ---
    for FILE in \
      "Challenge API JAR|${CHALLENGE_URL}"
    do
      NAME="${FILE%%|*}"
      URL="${FILE##*|}"
      echo "Uploading asset: ${NAME} → ${URL}"
      curl --fail --show-error --silent --request POST --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" --data "name=${NAME}&url=${URL}" "http://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/releases/${LATEST_TAG}/assets/links"
      done

    echo "All JARs attached successfully to release ${LATEST_TAG}."

# -------- Approval Stage (Notify Developer to Review Release Note) --------
Notify_Dev_Release_Note:
  stage: approval
  tags:
    - <Runner_Tag>
  dependencies: []
  variables:
    GIT_STRATEGY: none
  script:
  - |
    LATEST_TAG=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" "http://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/repository/tags" | jq -r '.[0].name')

    RELEASE_URL="${CI_PROJECT_URL}/-/releases/${LATEST_TAG}"
    PIPELINE_URL="${CI_PROJECT_URL}/-/pipelines/${CI_PIPELINE_ID}"

    EMAIL_BODY="A new release note is available for review.

    Please review and approve the release manually in GitLab.

    Release Note: ${RELEASE_URL}
    Pipeline: ${PIPELINE_URL}
    Release Tag: ${LATEST_TAG}
    Project: ${CI_PROJECT_NAME}

    Thanks,
    DevOps Team"

    echo -e "${EMAIL_BODY}" | mailx -v \
      -s "Release Note Review Required: ${LATEST_TAG}" \
      -S smtp="$SMTP_HOST" \
      -S smtp-port=587 \
      -S smtp-use-starttls \
      -S smtp-auth=login \
      -S smtp-auth-user="$SMTP_USER" \
      -S smtp-auth-password="$MAIL_PASS" \
      -S from="$FROM_EMAIL" \
      "$TO_EMAIL"

  - echo "Release Note Review email sent to OpenACS Dev"

# -------- Approval Stage (Manual Release Note Approval Gate ) --------
Review_Release_Note:
  stage: approval
  tags:
    - <Runner_Tag>
  when: manual
  dependencies: []
  variables:
    GIT_STRATEGY: none
  script:
    - |
      LATEST_TAG=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" "http://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/repository/tags" | jq -r '.[0].name')

      echo "Release Note Approved by: ${GITLAB_USER_NAME}"
      echo "Latest Tag: ${LATEST_TAG}"

# -------- Notify Stage (Send Approved Release Note to DevOps) --------
send_release_note:
  stage: notify
  tags:
    - <Runner_Tag>
  dependencies: []
  variables:
    GIT_STRATEGY: none
  needs:
    - Review_Release_Note
  script:
    - echo "Sending Release Note Email to DevOps..."
    - |
      LATEST_TAG=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PAT_TOKEN" "http://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/repository/tags" | jq -r '.[0].name')

      RELEASE_URL="${CI_PROJECT_URL}/-/releases/${LATEST_TAG}"
      EMAIL_BODY="Please find attached the Release Notes (${RELEASE_URL}), kindly update your Production Environment with the following updated JARS.
      Release Tag: ${LATEST_TAG}
      Pipeline ID: ${CI_PIPELINE_ID}
      Project: ${CI_PROJECT_NAME}
      
      Thanks,
      OpenACS DevOps Team"

      echo -e "${EMAIL_BODY}" | mailx -v \
        -s "New Release for Production - ${LATEST_TAG} ($(date +'%Y-%m-%d %H:%M'))" \
        -S smtp="$SMTP_HOST" \
        -S smtp-port=587 \
        -S smtp-use-starttls \
        -S smtp-auth=login \
        -S smtp-auth-user="$SMTP_USER" \
        -S smtp-auth-password="$MAIL_PASS" \
        -S from="$FROM_EMAIL" \
        -c "$TO_EMAIL" \
        "$TO_EMAIL"

    - echo "Release Note Email sent successfully to DevOps Team!"
```

> Add the defined variables in the GitLab Variables.