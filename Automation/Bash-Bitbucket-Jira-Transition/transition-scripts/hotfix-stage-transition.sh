#!/bin/bash

echo "Stage Transition Pipeline running from Jira Automation."

# Get the issues in the "Stage Deployment" status with the fixVersion in the released versions
JQL_QUERY='status = "Stage Deployment" AND fixVersion in (unreleasedVersions(), releasedVersions())'
# URL-encode the JQL query
ENCODED_JQL_QUERY=$(echo "$JQL_QUERY" | jq -sRr @uri)

ISSUE_KEYS=$(curl --request GET --url "$JIRA_BASE_URL/rest/api/3/search?jql=$ENCODED_JQL_QUERY" --header "Accept: application/json" --header "Authorization: Basic $JIRA_API_TOKEN" | jq -r '.issues[].key')

echo -e "Hotfix Issues in Stage Deployment status: \n"
echo -e "$ISSUE_KEYS"

# Environment Variables
# These variables are required for the script to function properly & these variables are store in bitbucket deployment variables
# BB_API_TOKEN → Bitbucket API authentication token
# JIRA_API_TOKEN → Jira API authentication token
# JIRA_BASE_URL → Jira project URL (e.g., https://yourcompany.atlassian.net)
# TRANSITION_ID → Jira transition ID for "Stage Testing"
# DEVOPS_TRANSITION_ID → Jira transition ID for reverting DevOps


# Declare the List of repositories
declare -a repos=("fort_backend" "fort_frontend" "fort_license")

# Global Variables to store the count of approved and merged pull requests for each repository
fort_backend_approved_status_count=0
fort_backend_merge_status_count=0
fort_frontend_approved_status_count=0
fort_frontend_merge_status_count=0
fort_license_approved_status_count=0
fort_license_merge_status_count=0


# Function to merge each pull request
merge_pull_request() {
    local REPO_BASE_URL=$1
    local PR_ID=$2
    local -n ref_APPROVED_STATUS_COUNT=$3
    local -n ref_MERGE_STATUS_COUNT=$4

    echo "Processing pull request $PR_ID from $REPO_BASE_URL"

    # Extract JIRA issue key from the pull request description
    ISSUE_KEY_REGEX="FORT-[0-9]+"
    ISSUE_SUMMARY=$(curl -s -H "Authorization: Basic $BB_API_TOKEN" "$REPO_BASE_URL/pullrequests/$PR_ID" | jq -r '.description')

    if [[ $ISSUE_SUMMARY =~ $ISSUE_KEY_REGEX ]]; then
        ISSUE_KEY=${BASH_REMATCH[0]}
        echo "Issue key: $ISSUE_KEY"

        # Get the status of the JIRA issue
        ISSUE_STATUS=$(curl -s -H "Authorization: Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/issue/$ISSUE_KEY" | jq -r '.fields.status.name')
        echo "ISSUE STATUS: $ISSUE_STATUS"

        if [[ "$ISSUE_STATUS" == "Stage Deployment" ]]; then

            # Check approval status of the pull requests and increment the approved status count
            APPROVAL_STATUS=$(curl -s -H "Authorization: Basic $BB_API_TOKEN" "$REPO_BASE_URL/pullrequests/$PR_ID" | jq -r '
                              .participants | map(select(.role == "REVIEWER")) |
				              any(.user.uuid == "{b55e5165-481g-4cc8-84a3-96c19de7d218}" and .approved == true) or
                              any(.user.uuid == "{6e57cf78-4141-698d-959d-8f3e5e8995aa}" and .approved == true)')
                
            echo -e "Approval Status: $APPROVAL_STATUS\n"

            if [[ "$APPROVAL_STATUS" == "true" ]]; then

                ((ref_APPROVED_STATUS_COUNT++))
                echo "Approved Status Count: $ref_APPROVED_STATUS_COUNT"

                # Merge the pull request if approved by all reviewers and increment the merge status count
                echo "Merging pull request $PR_ID."
                MERGE_URL="$REPO_BASE_URL/pullrequests/$PR_ID/merge"
                MERGE_RESPONSE=$(curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" "$MERGE_URL")
                MERGE_STATUS=$(echo "$MERGE_RESPONSE" | jq -r '.state')

                echo "Merge status for the PR: $PR_ID is $MERGE_STATUS"

                if [[ "$MERGE_STATUS" == "MERGED" ]]; then
                    ((ref_MERGE_STATUS_COUNT++))
                    echo "Merged Pull Request Count: $ref_MERGE_STATUS_COUNT"
                    echo "PR: $PR_ID Merged Successfully"
                else
                    # If merge status is not "MERGED", then there are merge conflicts, Revert the DevOps transition from Stage Testing to Testing
                    echo "Merge Conflicts for the PR: $PR_ID"
                fi
                    
            else
                echo "PR: $PR_ID is not approved by all of the reviewers."
            fi

        else
            echo "PR for Issue $ISSUE_KEY is not in Stage Deployment status."
        fi
    
    else 
        echo "Jira Issue key not found for PR $PR_ID."
    fi
}

process_repository(){
    local repo=$1
    local REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"
    
    # Remove the branch restriction from the stage branch
    BRANCH_RESTRICTION_URL="$REPO_BASE_URL/branch-restrictions"
    BRANCH_PATTERN="stage"
    echo "Removing branch restriction: $BRANCH_PATTERN from $repo."
    curl -s -X GET -H "Authorization:Basic $BB_API_TOKEN" --url "$BRANCH_RESTRICTION_URL" | jq -r '.values[] | select(.pattern == "'"$BRANCH_PATTERN"'") | .id' | while read -r branch_restriction_id; do
        curl -s -X DELETE -H "Authorization:Basic $BB_API_TOKEN" --url "$BRANCH_RESTRICTION_URL/$branch_restriction_id"
    done
    
    echo "Checking OPEN Hotfix PRs for Repository: $repo"

    # Get the OPEN PRs with the source branch starting with "hotfix/" and destination branch as "stage"
    OPEN_PRS=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50" --header "Authorization: Basic $BB_API_TOKEN" | jq -r '.values[] | select(.state=="OPEN" and .destination.branch.name == "stage" and (.source.branch.name | startswith("hotfix/"))) | .id')
    echo -e "OPEN PRS: $OPEN_PRS\n"
    
    APPROVED_STATUS_COUNT=0
    MERGE_STATUS_COUNT=0

    for PR in $OPEN_PRS; do
        merge_pull_request $REPO_BASE_URL $PR APPROVED_STATUS_COUNT MERGE_STATUS_COUNT
    done

    echo -e "Total Approved Pull Requests in $repo: $APPROVED_STATUS_COUNT. \n"
    echo -e "Total Merged Pull Requests in $repo: $MERGE_STATUS_COUNT. \n"

    if [[ $repo == ${repos[0]} ]]; then
        fort_backend_approved_status_count=$APPROVED_STATUS_COUNT
        fort_backend_merge_status_count=$MERGE_STATUS_COUNT
    elif [[ $repo == ${repos[1]} ]]; then
        fort_frontend_approved_status_count=$APPROVED_STATUS_COUNT
        fort_frontend_merge_status_count=$MERGE_STATUS_COUNT
    elif [[ $repo == ${repos[2]} ]]; then
        fort_license_approved_status_count=$APPROVED_STATUS_COUNT
        fort_license_merge_status_count=$MERGE_STATUS_COUNT
    fi

}


# Function to create a pull request from the stage branch to the prod/dev branch
create_pull_requests(){
    local REPO=$1
    local BRANCH=$2
    REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$REPO"

    # Create Pull Request
    PR_PAYLOAD="{\"title\": \"Pull request for: Stage to $BRANCH\", \"source\": {\"branch\": {\"name\": \"stage\"}}, \"destination\": {\"branch\": {\"name\": \"$BRANCH\"}}, \"description\": \"Created by BitBucket REST API\", \"close_source_branch\": false, \"reviewers\":[{\"display_name\": \"Fort Admin\", \"uuid\": \"{b55e5165-481g-4cc8-84a3-96c19de7d218}\" }, { \"display_name\": \"Fahad\", \"uuid\": \"{6e57cf78-4141-698d-959d-8f3e5e8995aa}\" }]}"

    RESPONSE=$(curl -X POST "$REPO_BASE_URL/pullrequests/" -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$PR_PAYLOAD")
    echo "PR Created Successfully in $REPO. with Pull Request ID:"	
    echo "$RESPONSE" | jq -r '.id'
}

# Deploy Stage branch to the Stage Environment
deploy_stage(){
    # Deploy the Stage branch to the Stage Environment in each repository
    REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"

    if [[ "$repo" == "fort_backend" ]]; then
        Pattern="stage-only-deploy"
    else
        Pattern="stage"
    fi
    curl -X POST "$REPO_BASE_URL/pipelines/" -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "{\"target\":{\"ref_type\":\"branch\", \"type\":\"pipeline_ref_target\",\"ref_name\":\"stage\", \"selector\":{\"type\":\"custom\",\"ref_type\":\"pipeline\",\"pattern\":\"$Pattern\"}}}"
}

# Transition the issues from Stage Deployment to Stage Testing
transition_issues(){
    echo "Transitioning all the Tickets from Stage Deployment to Stage Testing."
    for ISSUE_KEY in $ISSUE_KEYS; do
        # Transition the issue
        TRANSITION_URL="$JIRA_BASE_URL/rest/api/2/issue/$ISSUE_KEY/transitions/"
        TRANSITION_PAYLOAD="{\"transition\": { \"id\": \"$TRANSITION_ID\" } }"
        curl -X POST -H "Authorization:Basic $JIRA_API_TOKEN" -H "Content-Type:application/json" -d "$TRANSITION_PAYLOAD" "$TRANSITION_URL"
    done

}

# Revert the DevOps transition if not all repositories have the same number of approved and merged pull requests
revert_devops_transition() {
    echo "Reverting the DevOps transition from Stage Testing to Testing for Hotfix since not all PRs are merged."

    JQL_QUERY='issuetype=DevOps AND status = "Stage Testing" AND "Deployment\u007f[Dropdown]" = "HotFix"'
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

# Function to apply branch restrictions on the stage branch
apply_branch_restrictions(){
    local REPO=$1
    # Restrict the current release branch in all repos.
    REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$REPO"
    BRANCH_PATTERN="stage"
    echo "Restricting the branch: $BRANCH_PATTERN in: $REPO."
    RESTRICTION_TYPES=("push" "restrict_merges" "force" "delete")
    
    BRANCH_RESTRICTION_URL="$REPO_BASE_URL/branch-restrictions"
    # Iterate over the restriction types and create branch restrictions
    for restriction_type in "${RESTRICTION_TYPES[@]}"; do
        echo -e "Adding restriction: $restriction_type on branch $BRANCH_PATTERN.\n"
        BRANCH_RESTRICTION_PAYLOAD="{\"kind\": \"$restriction_type\", \"type\": \"branchrestriction\", \"pattern\": \"$BRANCH_PATTERN\", \"users\": [], \"groups\": []}"
        curl -s -X POST  -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$BRANCH_RESTRICTION_PAYLOAD"  --url "$BRANCH_RESTRICTION_URL"
    done
}


for repo in "${repos[@]}"; do

    process_repository $repo

done # End of for loop for repos


# Check if the Approved and Merged PRs are equal for each repository
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

        # Transition the issues from Stage Deployment to Stage Testing
        transition_issues
        
        for repo in "${repos[@]}"; do

            # echo "Deploying Stage on Stage Server in $repo."
            # deploy_stage "$repo"

            echo "Creating pull requests from stage to prod and dev in $repo."
            create_pull_requests $repo "prod"
            create_pull_requests $repo "dev"

            echo "Re-applying branch restrictions on the stage branch of $repo."
            apply_branch_restrictions "$repo"
                
        done

        for repo in "${repos[@]}"; do
            REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"
            echo "Checking PRs for repository: $repo"
            PR_ID_PROD=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50" --header "Authorization: Basic $BB_API_TOKEN" | jq -r '.values[] | select(.state=="OPEN" and .destination.branch.name == "prod" and (.source.branch.name == "stage")) | .id')
            PR_ID_DEV=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50" --header "Authorization: Basic $BB_API_TOKEN" | jq -r '.values[] | select(.state=="OPEN" and .destination.branch.name == "dev" and (.source.branch.name == "stage")) | .id')

            if [[ -n "$PR_ID_PROD" && -n "$PR_ID_DEV" ]]; then
                echo "Deploying stage for repository: $repo"
                deploy_stage "$repo"
            else
                echo "Stage to Dev and Stage to Prod PRs do not exist for $repo. Skipping deployment."
            fi
        done
fi

echo -e "Hotfix Stage Transition Script completed successfully. \n"
