# Multi Environment Gitlab CICD

This GitLab CI/CD pipeline is designed to build Docker images and deploy applications to different environments (**dev**, **QA**, and **staging**) using Coolify. The pipeline runs on an `Ubuntu 22.04` image and consists of two stages: `build` and `deploy`

## `.gitlab-ci.yml` file

```yaml
image: ubuntu:22.04

stages:
  - build
  - deploy


# Shared Build Template
.build_template:
  stage: build
  tags:
    - docker # Ensure this tag is assigned to a runner with Docker capabilities
  script:
    - echo "Docker Login..."
    - echo "$REGISTRY_PASSWORD" | docker login -u "$REGISTRY_USER" --password-stdin $REGISTRY
    - echo "Running Docker build steps..."
    - REGISTRY_URL="registry.gitlab.com/mygroup/myproject"
    - IMAGE_NAME="$IMAGE_NAME"
    - docker build -t $REGISTRY_URL/$IMAGE_NAME:$CI_COMMIT_TAG .
    - docker push $REGISTRY_URL/$IMAGE_NAME:$CI_COMMIT_TAG
    - echo "Docker build completed and push successfully"
    - docker tag $REGISTRY_URL/$IMAGE_NAME:$CI_COMMIT_TAG $REGISTRY_URL/$IMAGE_NAME:latest
    - docker push $REGISTRY_URL/$IMAGE_NAME:latest
    - echo "Docker image tagged as latest and pushed successfully"

# Shared Deploy Template For Coolify Environments
.deploy_template:
  stage: deploy
  tags:
    - shell # Ensure this tag is assigned to a runner with shell capabilities
  script:
    - echo "Install curl for webhook calls..."
    - apt-get update && apt-get install -y curl
    - echo "Triggering Coolify deployment..."
    - |
      RESPONSE=$(curl -sS -o response.txt -w "%{http_code}" \
        -X GET --header 'Authorization: Bearer "$COOLIFY_API_TOKEN"' "$COOLIFY_WEBHOOK" )

      echo "HTTP Status: $RESPONSE"

      if [ "$RESPONSE" -ne 200 ] && [ "$RESPONSE" -ne 201 ]; then
        echo "Coolify deployment failed"
        cat response.txt
        exit 1
      fi

      echo "Coolify deployment triggered successfully"


## Dev environment (triggers on dev or manual)

# Build 
build_dev:
  extends: .build_template
  environment:
    name: dev
  rules:
    - if: '$CI_COMMIT_BRANCH == "dev"'
      when: on_success
    - when: never
  variables:
    IMAGE_NAME: myapp-dev

# Deploy
deploy_dev:
  extends: .deploy_template
  environment:
    name: dev
  needs: ["build_dev"]
  variables:
    COOLIFY_WEBHOOK: $COOLIFY_DEV_WEBHOOK
  rules:
    - if: '$CI_COMMIT_BRANCH == "dev"'
      when: on_success
    - when: never


## QA environment (triggers on qa branch or manual)

# Build
build_qa:
  extends: .build_template
  environment:
    name: qa
  rules:
    - if: '$CI_COMMIT_BRANCH == "qa"'
      when: on_success
    - when: never
  variables:
    IMAGE_NAME: myapp-qa

# Deploy
deploy_qa:
  extends: .deploy_template
  environment:
    name: qa
  needs: ["build_qa"]
  variables:
    COOLIFY_WEBHOOK: $COOLIFY_QA_WEBHOOK
  rules:
    - if: '$CI_COMMIT_BRANCH == "qa"'
      when: on_success
    - when: never


# Staging environment (triggers on staging branch or manual)

# build

build_staging:
  extends: .build_template
  environment:
    name: staging
  rules:
    - if: '$CI_COMMIT_BRANCH == "staging"'
      when: on_success
    - when: never
  variables:
    IMAGE_NAME: myapp-staging

# deploy
deploy_staging:
  extends: .deploy_template
  environment:
    name: staging
  needs: ["build_staging"]
  variables:
    COOLIFY_WEBHOOK: $COOLIFY_STAGING_WEBHOOK
  rules:
    - if: '$CI_COMMIT_BRANCH == "staging"'
      when: on_success
    - when: never
```

### Explanation

#### Build Template (.build_template)

- Uses a GitLab Runner with the `docker` tag
- Logs in to the Docker registry
- Tags the Environment-specific image name (IMAGE_NAME)
- Pushes the images to the GitLab Container Registry.

#### Deploy Template (.deploy_template)

- Uses a GitLab Runner with the `shell` tag.
- Install curl.
- Sends an HTTP GET request to a Coolify webhook.

