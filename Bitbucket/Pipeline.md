# 📘 Bitbucket Pipeline Guide

## Bitbucket Pipelines
**Bitbucket Pipelines** is an integrated **CI/CD service** built into Bitbucket Cloud, enabling teams to automatically build, test, and deploy code in response to changes pushed to a repository.  
A pipeline is defined using a YAML file called `bitbucket-pipelines.yml`, which is located at the **root** of your repository.  
Instead of managing your own build servers or third-party CI tools, Bitbucket Pipelines provides a managed environment to automate workflows directly within your repository.  

**Key features:**  
- **Native CI/CD in Bitbucket** –> No need for external integration.
- **Configuration as Code** –> Pipelines are defined in `bitbucket-pipelines.yml`
- **Docker-based builds** –> Each build runs in a Docker container
- **Flexibility** –> Supports multiple branches, environments, and custom steps.
- **Integrations** –> Connect with Jira, Trello, Slack, AWS, Azure, GCP, and more.
- **Deployment Environments** –> Define staging, production, and custom environments.
- **Parallel Steps & Caching** –> Speed up builds with caching and concurrent steps.
- **Security** –> Use secure environment variables and deployment permissions.  

**Get started with Bitbucket Pipelines**  
[Official Documentation](https://support.atlassian.com/bitbucket-cloud/docs/get-started-with-bitbucket-pipelines/)

## General Syntax & Pipeline Types

```yaml
image: <base-docker-image>     # Base Docker image for pipeline steps

pipelines:
  default:                     # Runs on every push if no other rules match
    - step:
        name: "Build & Test"
        script:
          - command1
          - command2

  branches:                    # Runs on specific branches
    master:
      - step:
          name: "Deploy to Production"
          deployment: production
          script:
            - ./deploy-prod.sh

  pull-requests:               # Runs on pull request events
    "**":
      - step:
          name: "Run PR Checks"
          script:
            - ./run-tests.sh

  custom:                      # Pipelines triggered manually or via Jira automation
    custom-pipeline-name:
      - step:
          name: "Custom Action"
          deployment: staging
          script:
            - ./custom-script.sh
```

## Pipeline Definition (Key Concepts)  

- **`image:`**  
  Defines the Docker image that provides the environment to run your steps.  
  Example: `atlassian/default-image:3` (official Bitbucket image with Git + build tools).  

- **`pipelines:`**  
  Main section that defines workflows.  

- **`step:`**  
  A block of commands (scripts) that run inside the Docker container.  

- **`deployment:`**  
  Links the step to a Bitbucket Deployment Environment (e.g., dev, stage, prod).  

- **`script:`**  
  The shell commands executed in the step.  

- **`custom:`**  
  Defines **manual pipelines** that do not run automatically but can be triggered manually or by Jira Automation/Webhooks.

## Environment Variables

Environment variables in Bitbucket Pipelines are a secure way to store sensitive information such as **API keys**, **database passwords**, **tokens**, and other configuration data. Instead of hardcoding secrets into your code, you can define them securely in Bitbucket and access them during pipeline execution.

### Repository Variables

- Defined at the repository level.
- Available to **all pipelines** within the repository.
- Useful for values that remain the same across all branches and deployments (e.g., API keys for third-party services).
- Configured in **Repository Settings** → **Repository Variables**.

**Example**:  
If you define `API_KEY=12345` as a repository variable, you can access it in your script:

```yaml
script:
  - echo $API_KEY
```

### Deployment Variables

- Defined per deployment environment (e.g., staging, production).
- Useful when values differ across environments, such as database URLs, API endpoints, or credentials.
- Configured in `Repository Settings` → `Deployments` → `Select Environment`.
- **Deployment variables override repository variables if the same key is defined in both.**

**Example:**

- Staging may use `DB_URL=staging.example.com`
- Production may use `DB_URL=prod.example.com`

Usage in pipeline:

```yaml
deployments:
  production:
    - step:
        name: Deploy to Production
        script:
          - echo "Connecting to $DB_URL"
          - ./deploy-prod.sh
```

**Key Point: Deployment variables override repository variables**

## Best Practices

- Keep pipelines fast by caching and running parallel steps.
- Use branch-specific rules for production and staging deployments.
- Secure secrets with environment variables (never hardcode them).
- Use separate deployment environments with permissions.
- Write small modular scripts instead of large monolithic ones.
- Use custom pipelines for manual jobs (e.g., database migrations). 

---

## Example Pipelines

### Custom Pipelines

#### Backend

```yaml
image: atlassian/default-image:3

pipelines:
  custom:
    prod:
      - step:
          name: Build and Push and Deploy on Production
          deployment: production
          script:
            - echo ${ACR_PASSWORD} | docker login ${ACR_NAMESPACE} --username "${ACR_USERNAME}" --password-stdin
            - IMAGE_NAME=fort_prod_backend
            - docker build . --file Prod.Dockerfile --tag ${IMAGE_NAME}
            - VERSION="${BITBUCKET_BUILD_NUMBER}"
            - IMAGE=${ACR_NAMESPACE}/${IMAGE_NAME}
            - docker tag "${IMAGE_NAME}" "${IMAGE}:${VERSION}"
            - docker push "${IMAGE}:${VERSION}"
            - docker tag "${IMAGE_NAME}" "${IMAGE}:latest"
            - docker push "${IMAGE}:latest"
          services:
            - docker
      - step:
          name: Trigger Sandbox pipeline
          deployment: trigger-sandbox
          script:
            - pipe: atlassian/trigger-pipeline:5.1.2
              variables:
                BITBUCKET_USERNAME: $BB_USERNAME
                BITBUCKET_APP_PASSWORD: $BB_PASSWORD
                REPOSITORY: 'fort_backend'
                REF_TYPE: 'branch'
                REF_NAME: $BITBUCKET_BRANCH
                CUSTOM_PIPELINE_NAME: 'sandbox'

    sandbox:
      - step:
          name: Deploy on Sandbox
          deployment: sandbox
          script:
            - pipe: atlassian/ssh-run:0.4.1
              variables:
                SSH_USER: $SSH_USER
                SERVER: $SSH_HOST
                SSH_KEY: $SSH_KEY
                COMMAND: |
                  cd $BACKEND_PATH
                  git stash
                  git fetch
                  git checkout $BITBUCKET_BRANCH
                  git pull
                  cd organization
                  sudo rm -rf node_modules
                  sudo docker exec -it -w /app $CONTAINER_NAME npm i -f
                  cd ..
                  sudo docker-compose restart

    stage:
      - step:
          name: "Sync Stage DB and FS to Prod"
          deployment: stage-prod-sync
          script:
            - pipe: atlassian/ssh-run:0.4.1
              variables:
                SSH_USER: $SSH_USER
                SERVER: $SSH_HOST
                SSH_KEY: $SSH_KEY
                COMMAND: |
                  cd $SCRIPT_PATH
                  bash copy_prod_db_fs.sh
      - step:
          name: Build and Push and Deploy on stage
          deployment: stage
          script:
            - echo ${ACR_PASSWORD} | docker login ${ACR_NAMESPACE} --username "${ACR_USERNAME}" --password-stdin
            - IMAGE_NAME=fort_stage_backend
            - docker build . --file Stage.Dockerfile --tag ${IMAGE_NAME}
            - VERSION="${BITBUCKET_BUILD_NUMBER}"
            - IMAGE=${ACR_NAMESPACE}/${IMAGE_NAME}
            - docker tag "${IMAGE_NAME}" "${IMAGE}:${VERSION}"
            - docker push "${IMAGE}:${VERSION}"
            - docker tag "${IMAGE_NAME}" "${IMAGE}:latest"
            - docker push "${IMAGE}:latest"
          services:
            - docker
    
    test:
      - step:
          name: "Deploying on test"
          deployment: test
          script:
            - pipe: atlassian/ssh-run:0.4.1
              variables:
                SSH_USER: $SSH_USER
                SERVER: $SSH_HOST
                SSH_KEY: $SSH_KEY
                COMMAND: |
                  cd $BACKEND_PATH
                  git stash
                  git fetch
                  git checkout $BITBUCKET_BRANCH
                  git pull
                  cd organization
                  echo "$SUDO_PASS" | sudo -S rm -rf node_modules
                  sudo docker exec -it -w /app $CONTAINER_NAME npm i -f
                  cd ..
                  sudo docker compose -p test restart

    dev:
      - step:
          name: "Deploying on dev"
          deployment: dev
          script:
            - pipe: atlassian/ssh-run:0.4.1
              variables:
                SSH_USER: $SSH_USER
                SERVER: $SSH_HOST
                SSH_KEY: $SSH_KEY
                COMMAND: |
                  cd $BACKEND_PATH
                  git stash
                  git fetch
                  git checkout $BITBUCKET_BRANCH
                  git pull
                  cd organization
                  echo "$SUDO_PASS" | sudo -S rm -rf node_modules
                  sudo docker exec -it -w /app $CONTAINER_NAME npm i -f
                  cd ..
                  sudo docker compose -p dev restart

```

This pipeline manages deployments to different environments (**prod**, **sandbox**, **stage**, **test**, **dev**) using Docker containers and SSH-based deployments.

**Pipeline Structure**

**Production Deployment (prod)**  

- Builds a Docker image using `Prod.Dockerfile`
- Tags the image with both **build number** and **"latest"**
- Pushes to Azure Container Registry (ACR)
- Triggers the sandbox pipeline automatically after completion (It neccessary because we want sandbox and Prod are on the same page)

**Sandbox Deployment (sandbox)**

- Uses SSH to connect to the target server
- Updates the code from the repository
- Removes node_modules and reinstalls dependencies inside a running container
- Restarts the Docker Compose services

**Stage Environment (stage)**

- First syncs production database and filesystem to stage (using a custom script)
- Then builds and pushes a Docker image using `Stage.Dockerfile`
- Similar tagging and pushing process as production

**Test Environment (test)**

- SSH-based deployment similar to sandbox
- Uses `sudo` with password authentication
- Targets a specific Docker Compose project named "test"
- Restarts the test environment containers

**Development Environment (dev)**

- Similar to test environment deployment
- Targets the "dev" Docker Compose project
- Restarts the development environment containers

#### Frontend
```yaml
image: atlassian/default-image:3

pipelines:
  custom:
    prod:
      - step:
          name: "Build"
          deployment: production
          size: "2x"
          script:
            - mv src/config/config.env.js src/config/config.js
            - nvm install 20
            - npm install --legacy-peer-deps
            - npm run build
            - cd build
            - zip -r ../fort-frontend-$BITBUCKET_BUILD_NUMBER.zip .
          artifacts: 
            - fort-frontend-*.zip
      - step:
          name: "Deploy to Azure"
          deployment: azure
          script:
            - pipe: microsoft/azure-web-apps-deploy:1.0.0
              variables:
                AZURE_APP_ID: $AZURE_APP_ID
                AZURE_PASSWORD: $AZURE_PASSWORD
                AZURE_TENANT_ID: $AZURE_TENANT_ID
                AZURE_RESOURCE_GROUP: $RESOURCE_GROUP
                AZURE_APP_NAME: $APP_NAME
                ZIP_FILE: 'fort-frontend-$BITBUCKET_BUILD_NUMBER.zip'
      - step:
          name: Trigger Sandbox pipeline
          deployment: trigger-sandbox
          script:
            - pipe: atlassian/trigger-pipeline:5.1.2
              variables:
                BITBUCKET_USERNAME: $BB_USERNAME
                BITBUCKET_APP_PASSWORD: $BB_PASSWORD
                REPOSITORY: 'fort_frontend'
                REF_TYPE: 'branch'
                REF_NAME: $BITBUCKET_BRANCH
                CUSTOM_PIPELINE_NAME: 'sandbox'

    sandbox:
      - step:
          name: "Sandbox Deployment Build"
          deployment: sandbox
          script:
            - export CI=false
            - mv src/config/config.env.js src/config/config.js
            - nvm install 20
            - npm install --legacy-peer-deps
            - npm run build
          artifacts:
            - build/**
      - step:
          name: "Build RSYNC to server"
          deployment: sandbox-rsync
          script:
            - pipe: atlassian/rsync-deploy:0.8.1
              variables:
                USER: $RSYNC_USER
                SERVER: $RSYNC_SERVER
                REMOTE_PATH: '/var/www/html/$BUILD_PATH'
                LOCAL_PATH: 'build/*'
                SSH_KEY: $SSH_KEY
                SSH_ARGS: '-o StrictHostKeyChecking=no'
      - step:
          name: "Nginx restart"
          deployment: sandbox-ssh
          script:
            - pipe: atlassian/ssh-run:0.4.1
              variables:
                SSH_USER: $SSH_USER
                SERVER: $SSH_HOST
                SSH_KEY: $SSH_KEY
                COMMAND: 'sudo service nginx restart'
                
    stage:
      - step:
          name: "Build"
          deployment: stage
          size: "2x"
          script:
            - mv src/config/config.env.js src/config/config.js
            - nvm install 20
            - npm install --legacy-peer-deps
            - npm run build
            - cd build
            - zip -r ../fort-frontend-$BITBUCKET_BUILD_NUMBER.zip .
          artifacts: 
            - fort-frontend-*.zip
      - step:
          name: "Deploy to Azure"
          deployment: azure
          script:
            - pipe: microsoft/azure-web-apps-deploy:1.0.0
              variables:
                AZURE_APP_ID: $AZURE_APP_ID
                AZURE_PASSWORD: $AZURE_PASSWORD
                AZURE_TENANT_ID: $AZURE_TENANT_ID
                AZURE_RESOURCE_GROUP: $RESOURCE_GROUP
                AZURE_APP_NAME: $APP_NAME
                ZIP_FILE: 'fort-frontend-$BITBUCKET_BUILD_NUMBER.zip'

    test:
      - step:
          name: "Test Deployment Build"
          deployment: test
          size: "2x"
          script:
            - export CI=false
            - mv src/config/config.env.js src/config/config.js
            - nvm install 20
            - npm install --legacy-peer-deps
            - npm run build
          artifacts:
            - build/**
      - step:
          name: "Build RSYNC to server"
          deployment: test-rsync
          script:
            - pipe: atlassian/rsync-deploy:0.8.1
              variables:
                USER: $RSYNC_USER
                SERVER: $RSYNC_SERVER
                REMOTE_PATH: '/var/www/html/$BUILD_PATH'
                LOCAL_PATH: 'build/*'
                SSH_KEY: $SSH_KEY
                SSH_ARGS: '-o StrictHostKeyChecking=no'
      - step:
          name: "Nginx restart"
          deployment: test-ssh
          script:
            - pipe: atlassian/ssh-run:0.4.1
              variables:
                SSH_USER: $SSH_USER
                SERVER: $SSH_HOST
                SSH_KEY: $SSH_KEY
                COMMAND: 'echo "$SUDO_PASS" | sudo -S service nginx restart'

    dev:
      - step:
          name: "Dev Deployment Build"
          deployment: dev
          size: "2x"
          script:
            - export CI=false
            - mv src/config/config.env.js src/config/config.js
            - nvm install 20
            - npm install --legacy-peer-deps
            - npm run build
          artifacts:
            - build/**
      - step:
          name: "Build RSYNC to server"
          deployment: dev-rsync
          script:
            - pipe: atlassian/rsync-deploy:0.8.1
              variables:
                USER: $RSYNC_USER
                SERVER: $RSYNC_SERVER
                REMOTE_PATH: '/var/www/html/$BUILD_PATH'
                LOCAL_PATH: 'build/*'
                SSH_KEY: $SSH_KEY
                SSH_ARGS: '-o StrictHostKeyChecking=no'
      - step:
          name: "Nginx restart"
          deployment: dev-ssh
          script:
            - pipe: atlassian/ssh-run:0.4.1
              variables:
                SSH_USER: $SSH_USER
                SERVER: $SSH_HOST
                SSH_KEY: $SSH_KEY
                COMMAND: 'echo "$SUDO_PASS" | sudo -S service nginx restart'

```
This pipeline handles building and deploying a frontend application to different environments using different deployment strategies:

- Production & Stage: Azure Web Apps deployment
- Sandbox, Test & Dev: RSYNC to servers + Nginx restart

**Pipeline Structure**

**Production Deployment (prod)**

- **Build Step**: 
  - Configures environment settings
  - Installs Node.js 20
  - Installs dependencies with legacy peer deps (for React compatibility)
  - Builds the application
  - Creates a zip artifact of the build

- **Azure Deployment**:
  - Uses Microsoft's Azure Web Apps deploy pipe
  - Deploys the zip file to Azure App Service

- **Pipeline Trigger**:
  - Automatically triggers the sandbox pipeline after successful deployment

**Sandbox Deployment (sandbox)** / **Test & Dev Deployments (test, dev)**
- **Build Step**:
  - Similar build process but with `CI=false` (avows build warnings from failing)
  - Creates build artifacts

- **RSYNC Deployment**:
  - Uses RSYNC to deploy built files to a server
  - Copies files to `/var/www/html/` directory

- **Nginx Restart**:
  - Restarts Nginx web server to apply changes

**Stage Deployment (stage)**

- **Same as Production**:
  - Builds and deploys to Azure (but likely to a staging slot)
  - Uses the same Azure Web Apps deployment process