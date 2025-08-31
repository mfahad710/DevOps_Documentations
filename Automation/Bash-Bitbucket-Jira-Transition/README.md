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

## release-deployment-transition

- All issues of the latest unreleased version are in `Deployment` state.
- All `stage` → `prod` and `stage` → `dev` pull requests (PRs) are approved and merged.
- If successful:
  - The Jira version is released.
  - New release branches are created in repositories.
  - Branch restrictions are applied.
  - PRs targeting old release branches are updated to the new release.
- If unsuccessful:
  - The Jira DevOps transition is reverted from `Deployment` → `Stage Testing`. 

```text
            ┌──────────────────────────────┐
            │   Start Script (Jira trigger)│
            └───────────────┬──────────────┘
                            ▼
           ┌─────────────────────────────────┐
           │ Get latest unreleased Jira version│
           └────────────────┬────────────────┘
                            ▼
           ┌─────────────────────────────────┐
           │ Collect issues with that version │
           │ in "Deployment" status           │
           └────────────────┬────────────────┘
                            ▼
           ┌─────────────────────────────────┐
           │ For each repo: check open PRs    │
           │ stage→prod AND stage→dev         │
           └────────────────┬────────────────┘
                            ▼
           ┌─────────────────────────────────┐
           │ For each PR:                     │
           │ - If OPEN: check approvals       │
           │   → merge if approved            │
           │   → else revert transition       │
           │ - If MERGED: count as merged     │
           └────────────────┬────────────────┘
                            ▼
          ┌───────────────────────────────────┐
          │ All PRs merged?                   │
          └───────────┬───────────┬──────────┘
                      │Yes        │No
                      ▼           ▼
   ┌───────────────────────────┐  ┌───────────────────────┐
   │ Check Jira issues:        │  │ Revert transition to  │
   │ all in Deployment?        │  │ "Stage Testing"       │
   └──────────────┬────────────┘  └───────────────────────┘
                  ▼
       ┌───────────────────────────┐
       │ Release Jira version       │
       └──────────────┬────────────┘
                      ▼
   ┌────────────────────────────────────┐
   │ For each repo:                      │
   │ - Create new release branch         │
   │ - Recreate PRs for new release      │
   │ - Update old PRs → new branch       │
   │ - Apply branch restrictions         │
   └────────────────────────────────────┘
                      ▼
            ┌─────────────────────┐
            │ End (Release done)  │
            └─────────────────────┘
``` 

## hotfix-stage-transition

This Bash script automates the Stage Transition Process from `Stage Deployment` → `Stage Testing` in Jira, while handling hotfix pull requests (PRs) across multiple Bitbucket repositories.

- Only Jira issues in `Stage Deployment` are transitioned.
- Hotfix PRs targeting the `stage` branch are merged automatically.
- If all repositories meet merge conditions, deployment & Jira transitions proceed.
- Otherwise, the pipeline reverts Jira DevOps transition and re-applies branch restrictions.

```text
                  ┌─────────────────────┐
                  │ Start Script        │
                  └───────┬─────────────┘
                          │
                          ▼
             ┌─────────────────────────┐
             │ Get Jira issues in      │
             │ status "Stage Deployment"│
             └───────┬─────────────────┘
                     │
         ┌───────────▼────────────┐
         │ For each repository    │
         │ (backend, frontend,    │
         │ license):              │
         └───────────┬────────────┘
                     │
                     ▼
        ┌───────────────────────────────┐
        │ Remove branch restrictions    │
        │ Get hotfix PRs → stage        │
        │ Merge if approved             │
        └───────────┬───────────────────┘
                    │
   ┌────────────────▼───────────────────┐
   │ Compare Approved vs Merged PRs     │
   └────────────────┬───────────────────┘
                    │
       ┌────────────┼───────────────┐
       │ Yes: Match │ No: Mismatch  │
       ▼            ▼
┌────────────────┐ ┌────────────────────────────┐
│ Transition Jira│ │ Revert DevOps transition   │
│ Issues → Stage │ │ Apply branch restrictions  │
│ Testing        │ │ Exit script                │
└───────┬────────┘ └────────────────────────────┘
        │
        ▼
┌───────────────────────────────┐
│ Create PRs (stage→prod, dev)  │
│ Deploy Stage via pipelines    │
│ Reapply branch restrictions   │
└───────────────────────────────┘
        │
        ▼
   ┌─────────────┐
   │ End Script  │
   └─────────────┘
```

## hotfix-deployment-transition

- Verifying Jira hotfix issues in `Deployment` status have valid **fixVersions**.
- Fetching open pull requests (PRs) from `Stage → Prod` and `Stage → Dev` in Bitbucket.
- Checking approval & merge status of those PRs.
- If all reviewers approved, merging PRs automatically.
- If PRs are unapproved/unmerged, reverting Jira’s DevOps transition and exiting.
- If all stage PRs merge successfully, creating new PRs from `Dev → Release/FIRST_UNRELEASED_VERSION`.

```text
                    ┌──────────────────────┐
                    │ Start Script         │
                    └─────────┬────────────┘
                              │
                              ▼
              ┌────────────────────────────────┐
              │ Get Jira issues: status=Deployment│
              │ Ensure fixVersion is released   │
              └─────────────────┬──────────────┘
                                │
                                ▼
               ┌─────────────────────────────────┐
               │ Extract repositories (hotfixes) │
               └─────────────────┬───────────────┘
                                 │
                     ┌───────────▼───────────┐
                     │ For each repository   │
                     └───────────┬───────────┘
                                 │
                                 ▼
                ┌─────────────────────────────────┐
                │ Find PRs: Stage→Prod & Stage→Dev │
                └─────────────────┬───────────────┘
                                 │
                ┌────────────────▼────────────────┐
                │ Check PR state:                  │
                │  - If OPEN → check approvals      │
                │  - If approved → Merge            │
                │  - If not approved → Revert Jira  │
                │  - If MERGED already → continue   │
                └────────────────┬─────────────────┘
                                 │
                                 ▼
                  ┌─────────────────────────┐
                  │ Update approved/merged   │
                  │ counters per repository  │
                  └───────────┬─────────────┘
                              │
                              ▼
           ┌─────────────────────────────────────────┐
           │ After all repos processed:               │
           │  Compare approved vs merged counts       │
           └───────────────────┬─────────────────────┘
                               │
               ┌───────────────┼───────────────────┐
               │ All merged    │ Some unmerged     │
               ▼               ▼
 ┌─────────────────────────┐  ┌────────────────────────────┐
 │ Get FIRST_UNRELEASED_   │  │ Call revert_devops_transition │
 │ VERSION from Jira        │  │ Move DevOps → Stage Testing  │
 │ Create PR: dev→release   │  │ Exit script                  │
 └───────────┬─────────────┘  └────────────────────────────┘
             │
             ▼
 ┌───────────────────────────┐
 │ Manual deploy hotfix to   │
 │ Production (outside script)│
 └───────────┬───────────────┘
             │
             ▼
        ┌────────────┐
        │ End Script │
        └────────────┘
```