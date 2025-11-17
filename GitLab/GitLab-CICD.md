# GitLab CI/CD

**CI/CD** is a continuous method of software development, where we continuously build, test, deploy, and monitor iterative code changes.

**GitLab** is a single application for the entire DevSecOps lifecycle, meaning we fulfill all the fundamentals for CI/CD in one environment. **GitLab CI/CD** is an integrated system within GitLab that provides tools for Continuous Integration (CI) and Continuous Delivery/Deployment (CD) of software. It automates the process of building, testing, and deploying code, streamlining the software development lifecycle.

## Configuration File

To use GitLab CI/CD, we start with a `.gitlab-ci.yml` file at the root of our project. This file specifies the **stages**, **jobs**, and **scripts** to be executed during our CI/CD pipeline. It is a **YAML** file with its own custom syntax.

In this file, We define variables, dependencies between jobs, and specify when and how each job should be executed.

A pipeline is defined in the `.gitlab-ci.yml file`, and executes when the file runs on a **runner**.

Pipelines are made up of stages and jobs:
- Stages define the order of execution. Typical stages might be build, test, and deploy.
- Jobs specify the tasks to be performed in each stage. For example, a job can compile or test code.

Pipelines can be triggered by various events, like commits or merges, or can be on schedule.

## Pipeline Types

- **Branch Pipelines**: Default on commit pushes.
- **Merge Request Pipelines**: Run in context of MR; enable only: `[merge_requests]` or `rules:` matching.
- **Detached Merge Request Pipelines**: Evaluate merge result (conflict detection); valuable for integration tests.
- **Child / Multi-Project Pipelines**: trigger: job that starts another pipeline (same or other project).
- **Scheduled Pipelines**: Cron-like triggers for periodic tasks.
- **Manual Pipelines**: Started by user or through Run dialog.
- **Auto DevOps Pipelines**: Opinionated end-to-end pipeline using build + deploy conventions.

## Sample Pipeline

```bash
build-job:
  stage: build
  script:
    - echo "Hello, $GITLAB_USER_LOGIN!"

test-job1:
  stage: test
  script:
    - echo "This job tests something"

test-job2:
  stage: test
  script:
    - echo "This job tests something, but takes more time than test-job1."
    - echo "After the echo commands complete, it runs the sleep command for 20 seconds"
    - echo "which simulates a test that runs 20 seconds longer than test-job1"
    - sleep 20

deploy-prod:
  stage: deploy
  script:
    - echo "This job deploys something from the $CI_COMMIT_BRANCH branch."
  environment: production
```

This pipeline shows four jobs: `build-job`, `test-job1`, `test-job2`, and `deploy-prod`. The comments listed in the echo commands are displayed in the UI when we view the jobs. The values for the predefined variables `$GITLAB_USER_LOGIN` and `$CI_COMMIT_BRANCH` are populated when the jobs run.

[Detail Explanation](https://docs.gitlab.com/ci/quick_start/)

## GitLab CI/CD examples

Find the different CI/CD pipeline templates for various programming languages in GitLab.  
[Example Pipelines](https://docs.gitlab.com/ci/examples/) 