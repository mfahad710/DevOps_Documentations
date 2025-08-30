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
