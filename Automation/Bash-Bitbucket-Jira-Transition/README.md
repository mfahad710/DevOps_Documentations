# Explanation of Each Script

## release-testing-transition

This script automates the Release Testing process (All tickets in `Release Deployment` are merge into `release/x.x.x.x` branch in each repository):

- Fetching the latest unreleased version from Jira.
- Processing pull requests (PRs) in Bitbucket repositories targeting the release branch.
- Checking approval & merge status of PRs.
- Updating Jira tickets and transitioning them.
- Deploying releases to test servers.
- Creating PRs from release branches to the staging branch.
- Reverting DevOps transitions if inconsistencies occur.  

The script ensures consistency across multiple repositories (`fort_backend`, `fort_frontend`, `fort_license`) before proceeding to staging.

## release-stage-transition

It is designed to handle the transition of **release branches** → **stage branch**, validate Jira ticket statuses, merge pull requests, deploy to stage environments, and then prepare `stage` → `dev/prod` pull requests.

- Fetching the latest unreleased Jira version.
- Checking that all Jira issues with that version are in the Stage Deployment state.
- Processing Bitbucket pull requests (`release/x.x.x.x` → `stage`).
- Ensuring PRs are approved & merged across repositories.
- Deploying the stage branch to stage environments.
- Transitioning Jira issues from `Stage Deployment` → `Stage Testing`.
- Creating PRs for `stage` → `dev` and `stage` → `prod`.
- Applying branch restrictions back on the **stage** branch.
- Reverting Jira DevOps transition if validations fail.  
