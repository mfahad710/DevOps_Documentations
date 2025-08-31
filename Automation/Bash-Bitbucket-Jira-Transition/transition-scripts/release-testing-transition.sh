#!/bin/bash

# This script is used to process repositories and pull requests for a release transition in the Fortrans project.
# It fetches the latest unreleased version from JIRA, retrieves open pull requests targeting the release branch of the latest version,
# checks the approval status of each pull request, merges approved pull requests, updates JIRA issues, and deploys the release on test servers.
# Creates a PR from release branch to stage branch in which repository that has changes
# If not all repositories have the same number of approved and merged pull requests, it reverts the DevOps transition.

# Environment Variables
# These variables are required for the script to function properly & these variables are store in bitbucket deployment variables
# BB_API_TOKEN → Bitbucket API authentication token
# JIRA_API_TOKEN → Jira API authentication token
# JIRA_BASE_URL → Jira project URL (e.g., https://yourcompany.atlassian.net)
# TRANSITION_ID → Jira transition ID for "Release Testing"
# DEVOPS_TRANSITION_ID → Jira transition ID for reverting DevOps


# Repositories array
declare -a repos=("fort_backend" "fort_frontend" "fort_license")

# Global Variables to store the count of approved and merged pull requests for each repository
fort_backend_approved_status_count=0
fort_backend_merge_status_count=0
fort_frontend_approved_status_count=0
fort_frontend_merge_status_count=0
fort_license_approved_status_count=0
fort_license_merge_status_count=0


# Function to process each pull request
merge_pull_request() {
    local REPO_BASE_URL=$1
    local PR_ID=$2
    local FIRST_UNRELEASED_VERSION=$3
    local -n PR_APPROVED_STATUS_COUNT=$4
    local -n PR_MERGE_STATUS_COUNT=$5
  

    echo "Processing pull request $PR_ID from $REPO_BASE_URL"

    # Extract JIRA issue key from the pull request description
    # Confirm that the PR associated with the JIRA issue is in the Release Deployment status
    # Check Approval status of the PR and merge the PR if it is approved
    ISSUE_KEY_REGEX="FORT-[0-9]+"
    ISSUE_SUMMARY=$(curl -s -H "Authorization: Basic $BB_API_TOKEN" "$REPO_BASE_URL/pullrequests/$PR_ID" | jq -r '.description')

    if [[ $ISSUE_SUMMARY =~ $ISSUE_KEY_REGEX ]]; then
        ISSUE_KEY=${BASH_REMATCH[0]}
        echo "Issue key: $ISSUE_KEY"

        # Get the status of the JIRA issue
        ISSUE_STATUS=$(curl -s -H "Authorization: Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/issue/$ISSUE_KEY" | jq -r '.fields.status.name')
        echo "ISSUE STATUS: $ISSUE_STATUS"

        if [[ "$ISSUE_STATUS" == "Release Deployment" ]]; then

            # Check approval status of the pull request

            # If all reviewers have approved it
            APPROVAL_STATUS=$(curl -s -H "Authorization: Basic $BB_API_TOKEN" "$REPO_BASE_URL/pullrequests/$PR_ID" | jq -r '.participants | map(select(.role == "REVIEWER")) | all(.approved==true)')

            # If any of the required reviewers have approved it
            # APPROVAL_STATUS=$(curl -s -H "Authorization: Basic $BB_API_TOKEN" "$REPO_BASE_URL/pullrequests/$PR_ID" | jq -r '
            #                   .participants | map(select(.role == "REVIEWER")) |
			#                   any(.user.uuid == "{USERUUID}" and .approved == true) or
			#                   any(.user.uuid == "{USERUUID}" and .approved == true)')

            echo -e "Approval Status: $APPROVAL_STATUS\n"

            if [[ "$APPROVAL_STATUS" == "true" ]]; then

                ((PR_APPROVED_STATUS_COUNT++))
                echo "Approved Status Count: $PR_APPROVED_STATUS_COUNT"

        
                # Merge the pull request
                echo "Merging pull request $PR_ID."
                MERGE_URL="$REPO_BASE_URL/pullrequests/$PR_ID/merge"
                MERGE_RESPONSE=$(curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" "$MERGE_URL")
                MERGE_STATUS=$(echo "$MERGE_RESPONSE" | jq -r '.state')

                echo "Merge status for the PR: $PR_ID is $MERGE_STATUS"

                if [[ "$MERGE_STATUS" == "MERGED" ]]; then
                    ((PR_MERGE_STATUS_COUNT++))
                    echo "Merged Pull Request Count: $PR_MERGE_STATUS_COUNT"
                    echo "PR: $PR_ID Merged Successfully"

                    # Update the JIRA issue with the latest version
                    curl --request PUT --url "$JIRA_BASE_URL/rest/api/2/issue/$ISSUE_KEY" -H "Authorization: Basic $JIRA_API_TOKEN" -H "Content-Type: application/json" -d "{ \"update\": { \"fixVersions\": [{ \"add\": { \"name\":\"$FIRST_UNRELEASED_VERSION\" }}]}}"
                    echo "Added Fix Version"

                    # Get the fix versions of the JIRA issue
                    FIX_VERSIONS=$(curl -s -H "Authorization:Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/issue/$ISSUE_KEY" | jq -r '.fields.fixVersions[].name')

                    # Check if the fix version of the ticket is not empty
                    if [[ -n "$FIX_VERSIONS"   ]]; then
                        echo "Transitioning issue to Release Testing"
                        # Transition the issue to Release Testing
                        TRANSITION_URL="$JIRA_BASE_URL/rest/api/2/issue/$ISSUE_KEY/transitions/"
                        TRANSITION_PAYLOAD="{\"transition\": { \"id\": \"$TRANSITION_ID\" } }"
                        curl -X POST -H "Authorization:Basic $JIRA_API_TOKEN" -H "Content-Type:application/json" -d "$TRANSITION_PAYLOAD" "$TRANSITION_URL"
                    else
                        echo "Fix Version is not Populated"
                    fi

                else
                    echo "Merge Conflicts for the PR: $PR_ID"
                fi
            else
                echo "PR: $PR_ID is not approved by all of the reviewers."
            fi
        else
            echo "Issue Status of the PR: $PR_ID is not Release Deployment."
        fi
    else
        echo "Jira Issue key not found for PR $PR_ID."  
    fi
}

# Previous Merged PR function
check_merged_release_prs() {
    local REPO_BASE_URL=$1
    local FIRST_UNRELEASED_VERSION=$2
    local -n MERGE_COUNT=$3
    local -n APPROVED_COUNT=$4

    # Get all merged PRs targeting the release branch
    MERGED_PRS=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=10&q=destination.branch.name=\"release/$FIRST_UNRELEASED_VERSION\"" --header "Authorization: Basic $BB_API_TOKEN" | jq -r '.values[] | select(.state == "MERGED") | .id' | wc -l)

    MERGE_COUNT=$MERGED_PRS

    # For merged PRs, we know they must have been approved, so set the same count
    APPROVED_COUNT=$MERGE_COUNT

    echo "Total merged PRs in release/$FIRST_UNRELEASED_VERSION: $MERGE_COUNT"
    echo "Total approved PRs in release/$FIRST_UNRELEASED_VERSION: $APPROVED_COUNT"
}

# Main function to process pull requests in each repository
process_repository() {

    local REPO_BASE_URL=$1
    local TOTAL_MERGED_PRS=0
    local TOTAL_APPROVED_PRS=0

    APPROVED_STATUS_COUNT=0
    MERGE_STATUS_COUNT=0

    echo "Processing repository: $REPO_BASE_URL"

    # Fetch the latest unreleased version from JIRA
    FIRST_UNRELEASED_VERSION=$(curl -s -H "Authorization: Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/project/FORT/versions" | jq -r '.[] | select(.released == false) | .name' | head -n 1)
    echo "Latest Version: $FIRST_UNRELEASED_VERSION"

    check_merged_release_prs "$REPO_BASE_URL" "$FIRST_UNRELEASED_VERSION" TOTAL_MERGED_PRS TOTAL_APPROVED_PRS

    # Remove the branch restriction on the release branch
    BRANCH_RESTRICTION_URL="$REPO_BASE_URL/branch-restrictions"
    BRANCH_PATTERN="release/$FIRST_UNRELEASED_VERSION"
    echo "Removing branch restriction: $BRANCH_PATTERN from $REPO_BASE_URL."
    curl -s -X GET -H "Authorization:Basic $BB_API_TOKEN" --url "$BRANCH_RESTRICTION_URL" | jq -r '.values[] | select(.pattern == "'"$BRANCH_PATTERN"'") | .id' | while read -r branch_restriction_id; do
        curl -s -X DELETE -H "Authorization:Basic $BB_API_TOKEN" --url "$BRANCH_RESTRICTION_URL/$branch_restriction_id"
    done


    # Fetch open pull requests that target the release branch of the latest version
    OPEN_PRS=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50" --header "Authorization: Basic $BB_API_TOKEN" | jq -r '.values[] | select(.state=="OPEN" and .destination.branch.name == "release/'$FIRST_UNRELEASED_VERSION'") | .id')
    echo -e "OPEN PRS: $OPEN_PRS\n"

    # Process each pull request
    for PR_ID in $OPEN_PRS; do
        merge_pull_request "$REPO_BASE_URL" "$PR_ID" "$FIRST_UNRELEASED_VERSION" APPROVED_STATUS_COUNT MERGE_STATUS_COUNT
    done

    # Add total merged PRs to the merge count
    MERGE_STATUS_COUNT=$((MERGE_STATUS_COUNT + TOTAL_MERGED_PRS))

    # Add total approve PRs to the approve count
    APPROVED_STATUS_COUNT=$((APPROVED_STATUS_COUNT + TOTAL_APPROVED_PRS))

    echo -e "Total Approved Pull Requests in $REPO_BASE_URL: $APPROVED_STATUS_COUNT. \n"
    echo -e "Total Merged Pull Requests in $REPO_BASE_URL: $MERGE_STATUS_COUNT. \n"

    # Update the count of approved and merged pull requests for the current repository
    if [[ "$REPO_BASE_URL" == "https://api.bitbucket.org/2.0/repositories/fort/${repos[0]}" ]]; then
        fort_backend_approved_status_count=$APPROVED_STATUS_COUNT
        fort_backend_merge_status_count=$MERGE_STATUS_COUNT
    elif [[ "$REPO_BASE_URL" == "https://api.bitbucket.org/2.0/repositories/fort/${repos[1]}" ]]; then
        fort_frontend_approved_status_count=$APPROVED_STATUS_COUNT
        fort_frontend_merge_status_count=$MERGE_STATUS_COUNT
    elif [[ "$REPO_BASE_URL" == "https://api.bitbucket.org/2.0/repositories/fort/${repos[2]}" ]]; then
        fort_license_approved_status_count=$APPROVED_STATUS_COUNT
        fort_license_merge_status_count=$MERGE_STATUS_COUNT
    fi

}

# Function to revert the DevOps transition if not all repositories have the same number of approved and merged pull requests
revert_devops_transition() {
    echo "Reverting the transition"

    JQL_QUERY='issuetype=DevOps AND status = "Testing" AND "Deployment\u007f[Dropdown]" = "Release"'
    ENCODED_JQL_QUERY=$(echo "$JQL_QUERY" | jq -sRr @uri)
    # Get the DevOps issue key in the Release Testing status
    DEVOPS_ISSUE_KEY=$(curl --request GET --url "$JIRA_BASE_URL/rest/api/3/search?jql=$ENCODED_JQL_QUERY" --header "Accept: application/json" --header "Authorization: Basic $JIRA_API_TOKEN" | jq -r '.issues[].key')

    echo "Devops Issue Key: $DEVOPS_ISSUE_KEY"

    DEVOPS_TRANSITION_URL="$JIRA_BASE_URL/rest/api/2/issue/$DEVOPS_ISSUE_KEY/transitions/"

    DEVOPS_TRANSITION_PAYLOAD="{\"transition\": { \"id\": \"$DEVOPS_TRANSITION_ID\" } }"

    curl -X POST -H "Authorization:Basic $JIRA_API_TOKEN" -H "Content-Type:application/json" -d "$DEVOPS_TRANSITION_PAYLOAD" "$DEVOPS_TRANSITION_URL"

    #Exit the script
    echo -e "Transition reverted successfully. \n"
    echo -e "Exiting the script."
    exit 1
}

# Function to deploy the release on test servers
deploy_release(){

    local REPO=$1

    echo "Deploying the Release on Test Servers in $REPO."
    
    REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$REPO"

    # Deploy on Test-1
    curl -X POST "$REPO_BASE_URL/pipelines/" -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "{\"target\":{\"ref_type\":\"branch\", \"type\":\"pipeline_ref_target\",\"ref_name\":\"release/$FIRST_UNRELEASED_VERSION\", \"selector\":{\"type\":\"custom\",\"ref_type\":\"pipeline\",\"pattern\":\"test-1\"}}}"

    # Deploy on Test-2
    curl -X POST "$REPO_BASE_URL/pipelines/" -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "{\"target\":{\"ref_type\":\"branch\", \"type\":\"pipeline_ref_target\",\"ref_name\":\"release/$FIRST_UNRELEASED_VERSION\", \"selector\":{\"type\":\"custom\",\"ref_type\":\"pipeline\",\"pattern\":\"test-2\"}}}"

}

# Function to apply branch restrictions on the release branch
apply_branch_restrictions(){
    local REPO=$1
    # Restrict the current release branch in all repos.
    REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$REPO"
    BRANCH_PATTERN="release/$FIRST_UNRELEASED_VERSION"
    echo "Restricting the branch: $BRANCH_PATTERN."
    RESTRICTION_TYPES=("push" "restrict_merges" "force" "delete")

    # BACKEND
    BRANCH_RESTRICTION_URL="$REPO_BASE_URL/branch-restrictions"
    # Iterate over the restriction types and create branch restrictions
    for restriction_type in "${RESTRICTION_TYPES[@]}"; do
        echo -e "Adding restriction: $restriction_type on branch $BRANCH_PATTERN.\n"
        BRANCH_RESTRICTION_PAYLOAD="{\"kind\": \"$restriction_type\", \"type\": \"branchrestriction\", \"pattern\": \"$BRANCH_PATTERN\", \"users\": [], \"groups\": []}"
        curl -s -X POST  -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$BRANCH_RESTRICTION_PAYLOAD"  --url "$BRANCH_RESTRICTION_URL"
    done
}

# Function to create a pull request from the release branch to the stage branch
create_pull_request_from_release_stage(){

    local REPO=$1
    local MERGE_STATUS_COUNT=$2

    if [[ "MERGE_STATUS_COUNT" -gt 0 ]]; then

        REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$REPO"
        echo "Creating a pull request from release branch to stage branch in $REPO."

        PR_PAYLOAD="{\"title\": \"Pull request for: release/$FIRST_UNRELEASED_VERSION to Stage\", \"source\": {\"branch\": {\"name\": \"release/$FIRST_UNRELEASED_VERSION\"}}, \"destination\": {\"branch\": {\"name\": \"stage\"}}, \"description\": \"Created by BitBucket REST API\", \"close_source_branch\": false, \"reviewers\":[{\"display_name\": \"Fort-Admin\", \"uuid\": \"{b55e5165-481g-4cc8-84a3-96c19de7d218}\" }, { \"display_name\": \"Fahad\", \"uuid\": \"{6e57cf78-4141-698d-959d-8f3e5e8995aa}\" }]}"
        
        # Create and display the response
        RESPONSE=$(curl -X POST "$REPO_BASE_URL/pullrequests/" -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$PR_PAYLOAD")
        echo "PR Created Successfully in $REPO. with Pull Request ID:"
        echo "$RESPONSE" | jq '.id'

        deploy_release "$repo"

    else
        echo "No merged PRs in $REPO. Skipping pull request creation."
    fi

}


# Iterate over each repository and process PRs in each repository
for repo in "${repos[@]}"; do
        REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"
        process_repository "$REPO_BASE_URL"
done

# Check if all repositories have the same number of approved and merged pull requests
if [[ $fort_backend_approved_status_count != $fort_backend_merge_status_count || $fort_frontend_approved_status_count != $fort_frontend_merge_status_count || $fort_license_approved_status_count != $fort_license_merge_status_count ]]; then
        echo "Not all repositories have the same number of approved and merged pull requests."
        
        # Revert the DevOps transition from Testing to To Do
        revert_devops_transition
        
        for repo in "${repos[@]}"; do
            echo "Re-applying branch restrictions on the release branch of $repo."
            apply_branch_restrictions "$repo"
        done
else
        echo "All repositories have the same number of approved and merged pull requests."
        
        for repo in "${repos[@]}"; do

            echo "Re-applying branch restrictions on the release branch of $repo."
            apply_branch_restrictions "$repo"

            echo "Creating a pull request from release branch to stage branch in $repo."
            # Pass the corresponding merge status count for each repo
            if [[ "$repo" == "${repos[0]}" ]]; then
                create_pull_request_from_release_stage "$repo" "$fort_backend_merge_status_count"
            elif [[ "$repo" == "${repos[1]}" ]]; then
                create_pull_request_from_release_stage "$repo" "$fort_frontend_merge_status_count"
            elif [[ "$repo" == "${repos[2]}" ]]; then
                create_pull_request_from_release_stage "$repo" "$fort_license_merge_status_count"
            fi
        done
fi
