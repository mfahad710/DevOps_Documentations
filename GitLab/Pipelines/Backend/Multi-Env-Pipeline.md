# Multi-Environment CI/CD Pipeline

The document explains how the multi-environment CI/CD pipeline works for the CMS Backend (crm-api, crm-acs-api) supporting Sandbox and Stage environments using separate GitLab CI YAML configurations.

We maintain two environments:
- Sandbox
- Stage

Both share the same codebase, but use different `application.yaml` configuration (environment-specific values).

To avoid duplicating pipelines, we created a multi-environment GitLab CI/CD architecture using:
- `.gitlab-ci.yml`: Main router file
- `.gitlab-ci-sandbox.yml`: Sandbox pipeline
- `.gitlab-ci-stage.yml`: Stage pipeline

The root pipeline dynamically includes the correct CI file based on the branch and trigger conditions.

## `.gitlab-ci.yml` File
This file decides which environment pipeline to load, ensures clean workflow logic and includes sandbox/stage pipelines only when required

```bash
workflow:
  rules:
    - if: '$CI_COMMIT_BRANCH == "<Sandbox_Branch_Name>" || $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "<Sandbox_Branch_Name>"'
      when: always

    - if: '$CI_COMMIT_REF_NAME == "<Stage_Branch_Name>" && ($CI_PIPELINE_SOURCE == "manual" || $CI_PIPELINE_SOURCE == "web")'
      when: always

    - when: never

include:
  - local: '/.gitlab-ci-sandbox.yml'
    rules:
      - if: '$CI_COMMIT_BRANCH == "<Sandbox_Branch_Name>" || $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "<Sandbox_Branch_Name>"'

  - local: '/.gitlab-ci-stage.yml'
    rules:
      - if: '$CI_COMMIT_REF_NAME == "<Stage_Branch_Name>" && ($CI_PIPELINE_SOURCE == "manual" || $CI_PIPELINE_SOURCE == "web")'

# ------- Dummy job to make GitLab validation (never runs)-------------------#
noop_job:
  stage: .pre
  script:
    - echo "No matching environment detected. Skipping execution."
  rules:
    - when: never
```

## `.gitlab-ci-sandbox.yml` File

The Sandbox pipeline is an automated CI/CD workflow that triggers on code pushes or merge requests to the sandbox branch, builds the affected services, deploys them to the Sandbox environment using environment-specific configurations, and sends a Slack notification summarizing the deployment status.

```bash
workflow:
  name: sandbox Pipeline

stages:
  - security_test
  - build_deploy
  - notify

#----------------Security Test Job------------------#
## SonareQube Scan
sonarqube_scan:
  stage: security_test
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
  image: maven-jdk17
  tags:
    - <RUnner_Tag>
  script:
    - echo "--------------Running SonarQube Scan--------------"
    - mvn clean package sonar:sonar -DskipTests -Dsonar.projectKey=$SONAR_PROJECT_KEY -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.login=$SONAR_TOKEN
  allow_failure: true

#----------------Build and Deploy Jobs------------------#

#--------crm-acs-api Build and Deploy--------#
crm-acs-api:
  stage: build_deploy
  rules:
    - if: '$CI_PIPELINE_SOURCE == "push" || $CI_PIPELINE_SOURCE == "merge_request_event"'
      changes:
        - crm-acs-api/**/*
        - cms-commons/**/*
        - cms-dao/**/*
      when: on_success
    - when: never
  tags:
    - <Runner_Tag>
  image: maven-jdk17
  environment:
    name: crm-acs-api-sandbox
  script:
    - echo "Building crm-acs-api..."
    - mvn clean install -pl crm-acs-api -am -DskipTests
    - echo "Prepare SSH key"
    - echo "$SSH_KEY" > key.pem
    - chmod 600 key.pem
    - echo "Add Sandbox server to known_hosts"
    - mkdir -p ~/.ssh
    - ssh-keyscan -H $SANDBOX_SSH_SERVER >> ~/.ssh/known_hosts
    - echo "Copy the jar file to the Sandbox server"
    - scp -o IdentitiesOnly=yes -i key.pem crm-acs-api/target/crm-acs-api.jar $SSH_USER@$SANDBOX_SSH_SERVER:/home/$SSH_USER/services-jars/crm-acs-api/
    - echo "Deployment on Sandbox Server"
    - |
      ssh -o IdentitiesOnly=yes -i key.pem $SSH_USER@$SANDBOX_SSH_SERVER << 'EOF'
      cd /home/$SSH_USER/services-jars/crm-acs-api/
      if [ -f crm-acs-api.jar ]; then echo "Latest jar file present"; else exit 1 ; fi
      cd /app/services/crm-acs-api
      timestamp=$(date +'%d%b%Y%H%M')
      if [ -f crm-acs-api.jar ]; then mv crm-acs-api.jar backups/Sandbox-crm-acs-api-$timestamp.jar; fi
      mv /home/$SSH_USER/services-jars/crm-acs-api/crm-acs-api.jar .
      systemctl restart crm-acs-api.service
      EOF
  artifacts:
    paths:
      - crm-acs-api/target/crm-acs-api.jar
      - crm-acs-api/application.yml
    expire_in: 1 week
  allow_failure: false

#--------crm-api Build and Deploy--------#
crm-api:
  stage: build_deploy
  rules:
    - if: '$CI_PIPELINE_SOURCE == "push" || $CI_PIPELINE_SOURCE == "merge_request_event"'
      changes:
        - crm-api/**/*
        - cms-commons/**/*
        - cms-dao/**/*
        - cms-validators/**/*
        - cms-model/**/*
      when: on_success
    - when: never
  tags:
    - <Runner_Tag>
  image: maven-jdk17
  environment:
    name: crm-api-sandbox
  script:
    - echo "Building crm-api..."
    - mvn clean install -pl crm-api -am -DskipTests
    - echo "Prepare SSH key"
    - echo "$SSH_KEY" > key.pem
    - chmod 600 key.pem
    - echo "Add Sandbox server to known_hosts"
    - mkdir -p ~/.ssh
    - ssh-keyscan -H $SANDBOX_SSH_SERVER >> ~/.ssh/known_hosts
    - echo "Copy the jar file to the Sandbox server"
    - scp -o IdentitiesOnly=yes -i key.pem crm-api/target/crm-api.jar $SSH_USER@$SANDBOX_SSH_SERVER:/home/$SSH_USER/services-jars/crm-api/
    - echo "Deployment on Sandbox Server"
    - |
      ssh -o IdentitiesOnly=yes -i key.pem $SSH_USER@$SANDBOX_SSH_SERVER << 'EOF'
      cd /home/$SSH_USER/services-jars/crm-api/
      if [ -f crm-api.jar ]; then echo "Latest jar file present"; else exit 1 ; fi
      cd /app/services/crm-api
      timestamp=$(date +'%d%b%Y%H%M')
      if [ -f crm-api.jar ]; then mv crm-api.jar backups/Sandbox-crm-api-$timestamp.jar; fi
      mv /home/$SSH_USER/services-jars/crm-api/crm-api.jar .
      systemctl restart crm-api.service
      EOF
  artifacts:
    paths:
      - crm-api/target/crm-api.jar
      - crm-api/application.yml
    expire_in: 1 week
  allow_failure: false

#--------Slack Notification Job--------#
slack_notify:
  stage: notify
  image: alpine:latest
  tags:
    - <Runner_Tag>
  needs:
    - job: crm-acs-api
      optional: true
      artifacts: false
    - job: crm-api
      optional: true
      artifacts: false
  rules:
    - if: '$CI_PIPELINE_SOURCE == "push" || $CI_PIPELINE_SOURCE == "merge_request_event"'
      when: always
    - when: never
  script:
    - echo "Installing jq..."
    - apk add --no-cache curl jq
    - echo "Fetching build_deploy job results..."
    - |
      jobs_success=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/pipelines/${CI_PIPELINE_ID}/jobs" | jq -r '.[] | select(.stage=="build_deploy" and .status=="success") | .name' | paste -sd "," -)
      jobs_failed=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/pipelines/${CI_PIPELINE_ID}/jobs" | jq -r '.[] | select(.stage=="build_deploy" and .status=="failed") | .name' | paste -sd "," -)
      if [ -z "$jobs_success" ]; then jobs_success="No Successful Jobs"; fi
      if [ -z "$jobs_failed" ]; then jobs_failed="No Failed Jobs - All Successful"; fi
      echo "Successful jobs: $jobs_success"
      echo "Failed jobs: $jobs_failed"
      payload=$(cat <<EOF
      {
        "text": "*CMS Backend Sandbox Pipeline Notification* \n\n
        *Project*: <${CI_PROJECT_NAME}> \n
        *Pipeline:* <${CI_PIPELINE_URL}|#${CI_PIPELINE_ID}> \n
        *Branch:* ${CI_COMMIT_REF_NAME}\n
        *Commit:* ${CI_COMMIT_SHORT_SHA} \n
        *Triggered By:* ${GITLAB_USER_NAME}\n\n
        *Successful build_deploy jobs:* ${jobs_success}\n
        *Failed build_deploy jobs:* ${jobs_failed}"
      }
      EOF
      )
      curl -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
  allow_failure: true
```


## `.gitlab-ci-stage.yml` File

The Stage pipeline is a manually triggered CI/CD workflow that builds and deploys updated services to the Stage environment using its dedicated configuration, ensuring controlled, approval-based deployments followed by a detailed Slack notification of the deployment results.

```bash
workflow:
  name: Stage Pipeline

stages:
  - build_deploy
  - notify

#----------------Build and Deploy Jobs------------------#

#--------crm-acs-api Build and Deploy--------#
crm-acs-api:
  stage: build_deploy
  rules:
    - if: '$CI_PIPELINE_SOURCE == "manual" || $CI_PIPELINE_SOURCE == "web"'
      changes:
        - crm-acs-api/**/*
        - cms-commons/**/*
        - cms-dao/**/*
      when: on_success
    - when: never
  tags:
    - <Runner_Tag>
  image: maven-jdk17
  environment:
    name: crm-acs-api-stage
  script:
    - echo "Building crm-acs-api..."
    - mvn clean install -pl crm-acs-api -am -DskipTests
    - echo "Deploying crm-acs-api..."
    - echo "Prepare SSH key"
    - echo "$SSH_KEY" > key.pem
    - chmod 600 key.pem
    - echo "Add Stage server to known_hosts"
    - mkdir -p ~/.ssh
    - ssh-keyscan -H $STAGE_SSH_SERVER >> ~/.ssh/known_hosts
    - echo "Copy the jar file to the Stage server"
    - scp -o IdentitiesOnly=yes -i key.pem crm-acs-api/target/crm-acs-api.jar $SSH_USER@$STAGE_SSH_SERVER:/home/$SSH_USER/services-jars/crm-acs-api/
    - echo "SSH into server and perform deployment steps"
    - |
      ssh -o IdentitiesOnly=yes -i key.pem $SSH_USER@$STAGE_SSH_SERVER << 'EOF'
      cd /home/$SSH_USER/services-jars/crm-acs-api/
      if [ -f crm-acs-api.jar ]; then echo "Latest jar file present"; else exit 1 ; fi
      cd /app/services/crm-acs-api
      timestamp=$(date +'%d%b%Y%H%M')
      if [ -f crm-acs-api.jar ]; then mv crm-acs-api.jar backups/Stage-crm-acs-api-$timestamp.jar; fi
      mv /home/$SSH_USER/services-jars/crm-acs-api/crm-acs-api.jar .
      systemctl restart crm-acs-api.service
      EOF
  artifacts:
    paths:
      - crm-acs-api/target/crm-acs-api.jar
    expire_in: 1 week
  allow_failure: false

#--------crm-api Build and Deploy--------#
crm-api:
  stage: build_deploy
  rules:
    - if: '$CI_PIPELINE_SOURCE == "manual" || $CI_PIPELINE_SOURCE == "web"'
      changes:
        - crm-api/**/*
        - cms-commons/**/*
        - cms-dao/**/*
        - cms-validators/**/*
        - cms-model/**/*
      when: on_success
    - when: never
  tags:
    - <Runner_Tag>
  image: maven-jdk17
  environment:
    name: crm-api-stage
  script:
    - echo "Building crm-api..."
    - mvn clean install -pl crm-api -am -DskipTests
    - echo "Deploying crm-api..."
    - echo "Prepare SSH key"
    - echo "$SSH_KEY" > key.pem
    - chmod 600 key.pem
    - echo "Add Stage server to known_hosts"
    - mkdir -p ~/.ssh
    - ssh-keyscan -H $STAGE_SSH_SERVER >> ~/.ssh/known_hosts
    - echo "Copy the jar file to the Stage server and restart the service"
    - scp -o IdentitiesOnly=yes -i key.pem crm-api/target/crm-api.jar $SSH_USER@$STAGE_SSH_SERVER:/home/$SSH_USER/services-jars/crm-api/
    - echo "SSH into server and perform deployment steps"
    - |
      ssh -o IdentitiesOnly=yes -i key.pem $SSH_USER@$STAGE_SSH_SERVER << 'EOF'
      cd /home/$SSH_USER/services-jars/crm-api/
      if [ -f crm-api.jar ]; then echo "Latest jar file present"; else exit 1 ; fi
      cd /app/services/crm-api
      timestamp=$(date +'%d%b%Y%H%M')
      if [ -f crm-api.jar ]; then mv crm-api.jar backups/Stage-crm-api-$timestamp.jar; fi
      mv /home/$SSH_USER/services-jars/crm-api/crm-api.jar .
      systemctl restart crm-api.service
      EOF
  artifacts:
    paths:
      - crm-api/target/crm-api.jar
    expire_in: 1 week
  allow_failure: false

#--------Slack Notification Job--------#
slack_notify:
  stage: notify
  image: alpine:latest
  tags:
    - <Runner_Tag>
  needs:
    - job: crm-acs-api
      optional: true
      artifacts: false
    - job: crm-api
      optional: true
      artifacts: false
  rules:
    - if: '$CI_PIPELINE_SOURCE == "manual" || $CI_PIPELINE_SOURCE == "web"'
      when: always
    - when: never
  script:
    - echo "Installing jq..."
    - apk add --no-cache curl jq
    - echo "Fetching build_deploy job results..."
    - |
      jobs_success=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/pipelines/${CI_PIPELINE_ID}/jobs" | jq -r '.[] | select(.stage=="build_deploy" and .status=="success") | .name' | paste -sd "," -)
      jobs_failed=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/pipelines/${CI_PIPELINE_ID}/jobs" | jq -r '.[] | select(.stage=="build_deploy" and .status=="failed") | .name' | paste -sd "," -)
      if [ -z "$jobs_success" ]; then jobs_success="No Successful Jobs"; fi
      if [ -z "$jobs_failed" ]; then jobs_failed="No Failed Jobs - All Successful"; fi
      echo "Successful jobs: $jobs_success"
      echo "Failed jobs: $jobs_failed"
      payload=$(cat <<EOF
      {
        "text": "*CMS Backend Stage Pipeline Notification* \n\n
        *Project*: <${CI_PROJECT_NAME}> \n
        *Pipeline:* <${CI_PIPELINE_URL}|#${CI_PIPELINE_ID}> \n
        *Branch:* ${CI_COMMIT_REF_NAME}\n
        *Commit:* ${CI_COMMIT_SHORT_SHA} \n
        *Triggered By:* ${GITLAB_USER_NAME}\n\n
        *Successful build_deploy jobs:* ${jobs_success}\n
        *Failed build_deploy jobs:* ${jobs_failed}"
      }
      EOF
      )
      curl -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
  allow_failure: true
```

> **Set the GitLab Variables ( GitLab Project → Settings → CI/CD → Variables )**