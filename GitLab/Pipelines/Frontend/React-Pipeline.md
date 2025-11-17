# Frontend Pipeline

When a developer pushes code to a specific branch or opens a merge request, the pipeline enters FAST mode, where it performs quick checks such as linting, running unit tests, performing a basic security scan using npm audit, building the frontend application, deploying it to the server through SCP and SSH, and finally sending a detailed notification to Slack with links to all generated reports.

- FAST pipeline
  - Triggered on:
    - Push to specific branch
    - Merge request

Jobs: **Lint** → **Unit Tests** → **Security (npm audit)** → **Build + Deploy** → **Slack notify**

When the pipeline is triggered on a scheduled run, it enters DEEP mode, where it performs a comprehensive code-quality analysis using SonarQube instead of the fast checks. This mode is intended for more intensive scanning that typically doesn't need to run on every push.

- DEEP pipeline
  - Triggered on: Scheduled run (cron job)

Jobs: **SonarQube scan**

## `.gitlab-ci.yml` File

```bash
workflow:
  name: Frontend Pipeline
  rules:
    - if: '$CI_COMMIT_BRANCH == "<Branch_Name>" && $CI_PIPELINE_SOURCE == "push" || $CI_PIPELINE_SOURCE == "merge_request_event"'
      variables:
        PIPELINE_TYPE: "fast"

    - if: '$CI_COMMIT_BRANCH == "<Branch_Name>" && $CI_PIPELINE_SOURCE == "schedule"'
      variables:
        PIPELINE_TYPE: "deep"

    - when: never

stages:
  - lint
  - test
  - security_test
  - build_deploy
  - notify

#---------------- Linting Job ----------------
lint:
  stage: lint
  rules:
    - if: '$PIPELINE_TYPE == "fast"'
  image: node:23
  tags:
    - <Runner_Tag>
  script:
    - echo "--------------Running Linting--------------"
    - npm i --legacy-peer-deps
    - npm run lint
  artifacts:
    when: always
    paths:
      - lint-report.html
    expire_in: 1 week
  allow_failure: true

# ---------------- Unit Test Job ----------------
unit_test:
  stage: test
  rules:
    - if: '$PIPELINE_TYPE == "fast"'
  image: node:23
  tags:
    - <Runner_Tag>
  script:
    - echo "--------------Running Unit Tests--------------"
    - npm i --legacy-peer-deps
    - npm run test:ci
  artifacts:
    when: always
    paths:
      - test-results
    reports:
      junit: test-results/junit.xml
    expire_in: 1 week
  dependencies: []
  allow_failure: false

# ---------------- Security Test Job ----------------
## Run npm audit
npm_audit:
  stage: security_test
  rules:
    - if: '$PIPELINE_TYPE == "fast"'
  image: node:23
  tags:
    - <Runner_Tag>
  script:
    - echo "--------------Running Security Tests--------------"
    - echo "Running npm audit for dependency vulnerabilities..."
    - npm audit --audit-level=high --json > npm-audit.json || true
  artifacts:
    when: always
    paths:
      - npm-audit.json
    expire_in: 1 week
  dependencies: []
  allow_failure: true

# ---------------- Security Test Job ----------------
## SonarQube analysis

sonar_scan:
  stage: security_test
  rules:
    - if: '$PIPELINE_TYPE == "deep"'
  image: sonarsource/sonar-scanner-cli:latest
  tags:
    - <Runner_Tag>
  script:
    - echo "--------------Running SonarQube Scan--------------"
    - sonar-scanner -Dsonar.projectKey=$SONAR_PROJECT_KEY -Dsonar.sources=. -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.login=$SONAR_TOKEN
  dependencies: []
  allow_failure: true

# ---------------- Build and Deploy Job ----------------
build_deploy:
  stage: build_deploy
  rules:
    - if: '$PIPELINE_TYPE == "fast"'
  image: node:23
  tags:
    - <Runner_Tag>
  environment:
    name: <ENV_Name>
  script:
    - echo "-------------- Running Build --------------"
    - npm i --legacy-peer-deps
    - CI=false npm run build
    - echo "Send Build to UAT Server through SCP"
    # Create key.pem file and set permissions
    - echo "$SSH_KEY" > key.pem
    - chmod 600 key.pem
    # Add UAT server to known_hosts
    - mkdir -p ~/.ssh
    - ssh-keyscan -H $UAT_SSH_SERVER >> ~/.ssh/known_hosts
    # Securely copy build artifacts to UAT server
    - scp -o IdentitiesOnly=yes -i key.pem -r build $SSH_USER@$UAT_SSH_SERVER:/home/$SSH_USER/frontend-builds/
    # Run remote deployment safely
    - |
      ssh -o IdentitiesOnly=yes -i key.pem $SSH_USER@$UAT_SSH_SERVER << 'EOF'
      set -e
      echo "-------------- Starting Remote Deployment --------------"
      cd /home/$SSH_USER/frontend-builds/

      if [ -d build ]; then
        echo "Build copied successfully"
      else
        echo "Build folder not found, aborting"
        exit 1
      fi

      cd /opt/frontend-ui
      timestamp=$(date +'%d%b%Y%H%M')

      if [ -d build ]; then
        echo "Taking backup: backups/build-$timestamp"
        sudo mv build backups/build-$timestamp
      fi

      echo "Deploying new build"
      sudo mv /home/$SSH_USER/frontend-builds/build .
      echo "Restarting PM2 service"
      sudo pm2 reload <Service_Name> || true
      echo "Deployment completed successfully!"
      EOF
      
  artifacts:
    when: always
    paths:
      - build
    expire_in: 1 day
  dependencies: []
  allow_failure: false

# ---------------- Notification Job ----------------
slack-notification:
  stage: notify
  rules:
    - if: '$PIPELINE_TYPE == "fast"'
  image: curlimages/curl:latest
  tags:
    - <RUnner_Tag>
  script:
    - echo "--------------Sending Slack Notification--------------"
    # Message text
    - |
      STATUS_EMOJI=":white_check_mark:"
      if [ "$CI_PIPELINE_STATUS" = "failed" ]; then STATUS_EMOJI=":x:"; fi
      COLOR="#36a64f"
      if [ "$CI_PIPELINE_STATUS" = "failed" ]; then STATUS_EMOJI=":x:"; COLOR="#FF0000"; fi

      curl -X POST -H 'Content-type: application/json' \
      --data "{
        \"attachments\": [
          {
            \"color\": \"$COLOR\",
            \"pretext\": \"$STATUS_EMOJI *$CI_PIPELINE_STATUS* - Frontend Pipeline\",
            \"fields\": [
              {\"title\": \"Project\", \"value\": \"$CI_PROJECT_NAME\", \"short\": true},
              {\"title\": \"Pipeline ID\", \"value\": \"<$CI_PIPELINE_URL|#$CI_PIPELINE_ID>\", \"short\": true},
              {\"title\": \"Branch\", \"value\": \"$CI_COMMIT_REF_NAME\", \"short\": true},
              {\"title\": \"Author\", \"value\": \"$GITLAB_USER_NAME\", \"short\": true},
              {\"title\": \"Lint Report\", \"value\": \"<${CI_PROJECT_URL}/-/jobs/artifacts/${CI_COMMIT_REF_NAME}/file/lint-report.html?job=lint|View>\", \"short\": true},
              {\"title\": \"Unit Tests\", \"value\": \"<${CI_PROJECT_URL}/-/jobs/artifacts/${CI_COMMIT_REF_NAME}/file/test-results/junit.xml?job=unit_test|View>\", \"short\": true},
              {\"title\": \"NPM Audit\", \"value\": \"<${CI_PROJECT_URL}/-/jobs/artifacts/${CI_COMMIT_REF_NAME}/file/npm-audit.json?job=npm_audit|View>\", \"short\": true}
            ]
          }
        ]
      }" \
      $SLACK_WEBHOOK_URL
  dependencies:
    - lint
    - unit_test
    - npm_audit
  allow_failure: true
```