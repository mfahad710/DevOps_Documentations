# Security Scan

This GitLab CI/CD pipeline is designed to perform automated security scanning during the development workflow. It triggers on pushes to a specified branch and on merge request events, ensuring that code changes are continuously evaluated for security risks.  
The pipeline contains a single security stage that runs two key scans: **Static Application Security Testing (SAST)** to detect vulnerabilities in the source code and **Secret Detection** to identify any exposed credentials such as API keys or tokens. Both jobs are configured with `allow_failure: true`, allowing the pipeline to continue even if security issues are detected, thereby providing visibility into risks without interrupting the development or deployment process.  

**Pipeline yaml file**

```bash
workflow:
  name: <Pipeline_Name>
  rules:
    - if: '$CI_COMMIT_BRANCH == "<Branch_Name>" && $CI_PIPELINE_SOURCE == "push" || $CI_PIPELINE_SOURCE == "merge_request_event"'

    - when: never

stages:
  - security

include:
  - template: Security/Secret-Detection.gitlab-ci.yml
  - template: Security/SAST.gitlab-ci.yml

# ---------------- SAST Scanning Job ----------------
sast:
  stage: security
  image:
    name: registry.gitlab.com/security-products/nodejs-scan:4
    pull_policy: if-not-present
  tags:
    - OpenACS_Docker
  variables:
    SAST_EXCLUDED_PATHS: 'node_modules,build,dist,public'
    SAST_EXCLUDED_ANALYZERS: ''
  allow_failure: true

# ---------------- Secret Detection Job ----------------
secret_detection:
  stage: security
  image:
    name: registry.gitlab.com/security-products/secrets:5
    pull_policy: if-not-present
  tags:
    - OpenACS_Docker
  variables:
    SECRET_DETECTION_HISTORIC_SCAN: 'false'
  allow_failure: true

# -------------------- SAST Variables (Global) --------------------
variables:
  SECURE_LOG_LEVEL: 'info'
  SAST_DISABLE_DIND: 'true'

```