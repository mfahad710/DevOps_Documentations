#!/bin/bash

echo "Stage Transition Pipeline running from Jira Automation."


# Function to revert the DevOps transition if not all repositories have the same number of approved and merged pull requests
revert_devops_transition() {
    echo "Reverting the transition"

    JQL_QUERY='issuetype=DevOps AND status = "Stage Testing" AND "Deployment\u007f[Dropdown]" = "Release"'
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

# Function to merge each pull request
merge_pull_request() {
    local REPO_BASE_URL=$1
    local PR_ID=$2
    local PR_STATE=$3
    local -n PR_APPROVAL_STATUS_COUNT=$4
    local -n PR_MERGE_STATUS_COUNT=$5

    echo "Processing pull request $PR_ID from $REPO_BASE_URL"

    if [[ "$PR_STATE" == "MERGED" ]]; then

        echo -e "PR: $PR_ID is already approved & merged. \n"
        ((PR_APPROVAL_STATUS_COUNT++))
        ((PR_MERGE_STATUS_COUNT++))

    elif [[ "$PR_STATE" == "OPEN" ]]; then

        echo -e "PR: $PR_ID is open. Checking approval status. \n"

        # Check approval status of the pull request
        APPROVAL_RESPONSE=$(curl -s -H "Authorization: Basic $BB_API_TOKEN" "$REPO_BASE_URL/pullrequests/$PR_ID" | jq -r '
				.participants | map(select(.role == "REVIEWER")) |
				any(.user.uuid == "{b55e5165-481g-4cc8-84a3-96c19de7d218}" and .approved == true) or
                any(.user.uuid == "{6e57cf78-4141-698d-959d-8f3e5e8995aa}" and .approved == true)')

        echo -e "Approval Status: $APPROVAL_RESPONSE\n"

        if [[ "$APPROVAL_RESPONSE" == "true" ]]; then

            ((PR_APPROVAL_STATUS_COUNT++))

            echo "Approved Count: $PR_APPROVAL_STATUS_COUNT"

            echo "Merging pull request $PR_ID."
            MERGE_URL="$REPO_BASE_URL/pullrequests/$PR_ID/merge"
            MERGE_RESPONSE=$(curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" "$MERGE_URL")
            MERGE_STATUS=$(echo "$MERGE_RESPONSE" | jq -r '.state')

            echo "Merge status for the PR: $PR_ID is $MERGE_STATUS"

            if [[ "$MERGE_STATUS" == "MERGED" ]]; then
                ((PR_MERGE_STATUS_COUNT++))
                echo "Merged Pull Request Count: $PR_MERGE_STATUS_COUNT"
                echo "PR: $PR_ID Merged Successfully"
            else
                echo "Merge Conflicts for the PR: $PR_ID"
            fi
            
        else
            echo "PR: $PR_ID is not approved by all of the reviewers."
        fi
    else
        echo "PR: $PR_ID is in $PR_STATE state. PR should be OPEN or MERGED."
    fi
 
}

create_pull_request(){


    local REPO=$1
    local destBranch=$2

    REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$REPO"

    echo "Creating a pull request from release branch to stage branch in $REPO."

    PR_PAYLOAD="{\"title\": \"Pull request for: stage to $destBranch\", \"source\": {\"branch\": {\"name\": \"stage\"}}, \"destination\": {\"branch\": {\"name\": \"$destBranch\"}}, \"description\": \"Created by BitBucket REST API\", \"close_source_branch\": false, \"reviewers\":[{\"display_name\": \"Fort Admin\", \"uuid\": \"{b55e5165-481g-4cc8-84a3-96c19de7d218}\" }, { \"display_name\": \"Fahad\", \"uuid\": \"{6e57cf78-4141-698d-959d-8f3e5e8995aa}\" }]}"

    # Create and display the response
    RESPONSE=$(curl -X POST "$REPO_BASE_URL/pullrequests/" -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$PR_PAYLOAD")
    echo "PR for stage to $destBranch created successfully in $REPO. with Pull Request ID:"
    echo "$RESPONSE" | jq '.id'
    
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


FIRST_UNRELEASED_VERSION=$(curl -s -H "Authorization:Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/project/FORT/versions" | jq -r '.[] | select(.released == false) | .name' | head -n 1)

ISSUE_KEYS=$(curl --request GET --url "$JIRA_BASE_URL/rest/api/3/search?jql=fixVersion=\"$FIRST_UNRELEASED_VERSION\"" --header "Accept: application/json" --header "Authorization: Basic $JIRA_API_TOKEN" | jq -r '.issues[].key')

echo -e "Latest Version: $FIRST_UNRELEASED_VERSION \n"
echo "Issue Keys: $ISSUE_KEYS"

# Check if all the issues with the unreleased version are in stage deployment status and no issue is in any other status.
all_issues_in_stage_deployment=true

for ISSUE_KEY in $ISSUE_KEYS; do
        ISSUE_STATUS=$(curl -s -H "Authorization: Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY" | jq -r '.fields.status.name')

        if [[ "$ISSUE_STATUS" != "Stage Deployment" ]]; then
                all_issues_in_stage_deployment=false
                break
        fi
done


# Transition Tickets form Stage Deployment to Stage Testing here.
if [[ "$all_issues_in_stage_deployment" == true ]]; then
    
    echo "All issues are in Stage Deployment. Proceeding with transition."
    # Merge the OPEN PRs [release/FIRST_UNRELEASED_VERSION to stage] with Status approved by all reviewers in each repository

    declare -a repos=("fort_backend" "fort_frontend" "fort_license")

    Repos_with_MERGED_PRs=()

    # Total OPEN PRs will be compared with Total Merged PRs to check if all PRs are merged
    # If Total OPEN PRs == Total Merged PRs, then all PRs are merged
    # If Total OPEN PRs != Total Merged PRs, then not all PRs are merged
    # If not all PRs are merged, then the script will not proceed to deploy the Stage branch to the Stage Environment
    # If not all PRs are merged, then revert back the DevOps transition from Stage Testing to Testing.
    # If all PRs are merged, then the script will deploy the Stage branch to the Stage Environment
    # When Stage branch is deployed to the Stage Environment, then the script will transition all the tickets from Stage Deployment to Stage Testing

    # Total_Repos=${#repos[@]}
    # echo "Total Repos: $Total_Repos"
    Total_Merged_PRs=0
    #Total_OPEN_PRs=0
    Total_Approved_PRs=0
    
    #echo "Number of open PRs: $Total_OPEN_PRs"


    for repo in "${repos[@]}"; do

        echo "Checking PRs for $repo"
        REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"


        # OPEN_PRS=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50" --header "Authorization: Basic $BB_API_TOKEN" | jq -r '.values[] | select(.state=="OPEN" and .source.branch.name == "release/'$FIRST_UNRELEASED_VERSION'" and .destination.branch.name == "stage") | .id')
        # echo -e "OPEN PRS: $OPEN_PRS\n"

        OPEN_PRS=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50&state=OPEN" \
        --header "Authorization: Basic $BB_API_TOKEN" \
        | jq -r --arg ver "release/$FIRST_UNRELEASED_VERSION" '.values[] | select(.source.branch.name == $ver and .destination.branch.name == "stage")')

        MERGED_PRS=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50&state=MERGED" \
        --header "Authorization: Basic $BB_API_TOKEN" \
        | jq -r --arg ver "release/$FIRST_UNRELEASED_VERSION" '.values[] | select(.source.branch.name == $ver and .destination.branch.name == "stage")')

        PRS="$OPEN_PRS"$'\n'"$MERGED_PRS"

        
        # Remove the branch restriction from the stage branch
        BRANCH_RESTRICTION_URL="$REPO_BASE_URL/branch-restrictions"
        BRANCH_PATTERN="stage"
        echo "Removing branch restriction: $BRANCH_PATTERN from $repo."
        curl -s -X GET -H "Authorization:Basic $BB_API_TOKEN" --url "$BRANCH_RESTRICTION_URL" | jq -r '.values[] | select(.pattern == "'"$BRANCH_PATTERN"'") | .id' | while read -r branch_restriction_id; do
            curl -s -X DELETE -H "Authorization:Basic $BB_API_TOKEN" --url "$BRANCH_RESTRICTION_URL/$branch_restriction_id"
        done

        
        # echo "$PRS" | jq -c '.' | while read -r pr; do
        while read -r pr; do

            APPROVED_STATUS_COUNT=0
            MERGE_STATUS_COUNT=0

            PR_ID=$(echo "$pr" | jq -r '.id')
            PR_STATE=$(echo "$pr" | jq -r '.state')
            echo "Processing PR ID: $PR_ID, State: $PR_STATE"
            merge_pull_request $REPO_BASE_URL $PR_ID $PR_STATE APPROVED_STATUS_COUNT MERGE_STATUS_COUNT

            echo "Approved Status Count for $repo: $APPROVED_STATUS_COUNT"
            echo "Merged Pull Request Count for $repo: $MERGE_STATUS_COUNT"

            if [[ $APPROVED_STATUS_COUNT -ne 0 || $MERGE_STATUS_COUNT -ne 0 ]]; then
                if [[ $APPROVED_STATUS_COUNT -eq $MERGE_STATUS_COUNT ]]; then
                    echo "All PRs are merged for $repo"
                    ((Total_Merged_PRs++))
                    echo "Total Merged PRs: $Total_Merged_PRs"
                    Repos_with_MERGED_PRs+=("$repo")
                else
                    echo "Not all PRs are merged for $repo"
                    echo "Total Merged PRs: $Total_Merged_PRs"
                fi
            else
                echo "PRs for release/$FIRST_UNRELEASED_VERSION to Stage is not merged for $repo."

            fi

        done < <(echo "$PRS" | jq -c '.')
        
    done # End of for loop for repos


    for repo in "${repos[@]}"; do

        REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"

        Approved_PR_Count=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50&state=MERGED" \
        --header "Authorization: Basic $BB_API_TOKEN" \
        | jq -r --arg ver "release/$FIRST_UNRELEASED_VERSION" '[.values[] | select(.source.branch.name == $ver and .destination.branch.name == "stage")] | length')

        echo "Open PR Count in ${repo} is: ${Approved_PR_Count}"
        Total_Approved_PRs=$((Total_Approved_PRs + Approved_PR_Count))
    done

    if [[ $Total_Merged_PRs -eq $Total_Approved_PRs ]]; then
        echo "All PRs for release/$FIRST_UNRELEASED_VERSION to Stage are merged."

        if [[ ${#Repos_with_MERGED_PRs[@]} -gt 0 ]]; then

            # Deploy the Stage branch to the Stage Environment
            echo "Deploying the Stage branch to the Stage Environment."
            for repo in "${Repos_with_MERGED_PRs[@]}"; do
                REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"

                if [[ "$repo" == "fort_backend" ]]; then
                    Pattern="stage-only-deploy"
                else
                    Pattern="stage"
                fi
                curl -X POST "$REPO_BASE_URL/pipelines/" -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "{\"target\":{\"ref_type\":\"branch\", \"type\":\"pipeline_ref_target\",\"ref_name\":\"stage\", \"selector\":{\"type\":\"custom\",\"ref_type\":\"pipeline\",\"pattern\":\"$Pattern\"}}}"
            done

        else
            echo "No repositories have merged PRs, skipping deployment."
            revert_devops_transition
        fi


        echo "Transitioning all the Tickets from Stage Deployment to Stage Testing."
        for ISSUE_KEY in $ISSUE_KEYS; do
                # Transition the issue
                TRANSITION_URL="$JIRA_BASE_URL/rest/api/2/issue/$ISSUE_KEY/transitions/"
                TRANSITION_PAYLOAD="{\"transition\": { \"id\": \"$TRANSITION_ID\" } }"
                curl -X POST -H "Authorization:Basic $JIRA_API_TOKEN" -H "Content-Type:application/json" -d "$TRANSITION_PAYLOAD" "$TRANSITION_URL"
        done

        echo "All Issues are in Stage Testing."


        # create PRs for stage to dev and Prod.
        for repo in "${Repos_with_MERGED_PRs[@]}"; do
            create_pull_request $repo "dev"
            create_pull_request $repo "prod"
            apply_branch_restrictions $repo
        done
        

    else
        echo "Not all PRs for release/$FIRST_UNRELEASED_VERSION to Stage are merged."
        # Revert back the DevOps transition from Stage Testing to Testing
        for repo in "${repos[@]}"; do
            apply_branch_restrictions $repo
        done
        echo "Reverting back the DevOps transition from Stage Testing to Testing."
        revert_devops_transition

    fi

else
        echo "Not All Issues are in Stage Deployment."
        for repo in "${repos[@]}"; do
            apply_branch_restrictions $repo
        done
        revert_devops_transition
fi

echo -e "Release Stage Transition Script completed successfully. \n"
