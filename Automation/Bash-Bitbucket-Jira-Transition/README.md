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