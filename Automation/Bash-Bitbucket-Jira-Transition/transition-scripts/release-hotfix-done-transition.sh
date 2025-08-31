#!/bin/bash

RELEASED_VERSION=$(curl -s -H "Authorization:Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/project/FORT/versions" | jq -r '.[] | select(.released == true) | .name' | tail -n 1)
echo "Released Version: $RELEASED_VERSION"

# GET all related issues that are in "Deployment" status
ISSUE_KEYS=$(curl --request GET --url "$JIRA_BASE_URL/rest/api/3/search?jql=status=\"Deployment\"" --header "Accept: application/json" --header "Authorization: Basic $JIRA_API_TOKEN" | jq -r '.issues[].key')

# Fetch the latest unreleased version from JIRA
FIRST_UNRELEASED_VERSION=$(curl -s -H "Authorization: Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/project/FORT/versions" | jq -r '.[] | select(.released == false) | .name' | head -n 1)
echo "Latest Version: $FIRST_UNRELEASED_VERSION"


echo "Transitioning the tickets from Deployment to Done."

# Check if all related issues are in "Deployment" status
all_issues_in_deployment=true

for ISSUE_KEY in $ISSUE_KEYS; do
	ISSUE_STATUS=$(curl -s -H "Authorization: Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY" | jq -r '.fields.status.name')

	if [[ "$ISSUE_STATUS" != "Deployment" ]]; then
		all_issues_in_deployment=false
		break
	else
		echo "ISSUE is in deployment status."
	fi

done

merge_pull_request(){
	local REPO_BASE_URL=$1
	local PR_ID=$2

	echo "Merging pull request $PR_ID."
	MERGE_URL="$REPO_BASE_URL/pullrequests/$PR_ID/merge"
	MERGE_RESPONSE=$(curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" "$MERGE_URL")
	MERGE_STATUS=$(echo "$MERGE_RESPONSE" | jq -r '.state')

	echo "Merge status for the PR: $PR_ID is $MERGE_STATUS"

	if [[ "$MERGE_STATUS" == "MERGED" ]]; then
		echo "PR: $PR_ID Merged Successfully"
	else
		echo "Merge Conflicts for the PR: $PR_ID"
		echo "Merge Response: $MERGE_RESPONSE"
	fi
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
# Transition the tickets from deployment to Done
echo "Transition the tickets from deployment to Done"

if [[ "$all_issues_in_deployment" == true ]]; then                
    for ISSUE_KEY in $ISSUE_KEYS; do
		# Transition the issue
		TRANSITION_URL="$JIRA_BASE_URL/rest/api/2/issue/$ISSUE_KEY/transitions/"
		TRANSITION_PAYLOAD="{\"transition\": { \"id\": \"$TRANSITION_ID\" } }"
		curl -X POST -H "Authorization:Basic $JIRA_API_TOKEN" -H "Content-Type:application/json" -d "$TRANSITION_PAYLOAD" "$TRANSITION_URL"
    done
    
    # Get OPEN PRs from all the repositories
	declare -a repos=("fort_backend" "fort_frontend" "fort_license")

	branch_restrictions_removed=false
	# Get OPEN PRs
	for repo in "${repos[@]}"; do
		REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"
		OPEN_PRS=$(curl --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50" \
						--header "Authorization: Basic $BB_API_TOKEN" \
						| jq -r '.values[] | select(.source.branch.name == "dev") | .id')

		for PR_ID in $OPEN_PRS; do
			# Get PR Destination Branch
			PR_DESTINATION_BRANCH=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests/$PR_ID" \
									--header "Authorization: Basic $BB_API_TOKEN" \
									| jq '.destination.branch.name')
			echo "PR: $PR_ID Destination Branch: $PR_DESTINATION_BRANCH"
			# Trim the quotes from the PR Destination Branch
			PR_DESTINATION_BRANCH=$(echo $PR_DESTINATION_BRANCH | tr -d '"')
			# Check if the PR is from dev to release branch
			# If the PR is from dev to release branch, remove the branch restriction on the release branch
			if [[ "$PR_DESTINATION_BRANCH" == "release/"* ]]; then
				echo "PR: $PR_ID is from dev to release branch."
				# Remove Branch Restrictions 
				branch_restrictions_removed=true
				# Remove the branch restriction on the release branch
				BRANCH_PATTERN="release/$FIRST_UNRELEASED_VERSION"
				BRANCH_RESTRICTION_URL="$REPO_BASE_URL/branch-restrictions"
				echo "Removing branch restriction: $BRANCH_PATTERN from $REPO_BASE_URL."
				curl -s -X GET -H "Authorization:Basic $BB_API_TOKEN" --url "$BRANCH_RESTRICTION_URL" | jq -r '.values[] | select(.pattern == "'"$BRANCH_PATTERN"'") | .id' | while read -r branch_restriction_id; do
					curl -s -X DELETE -H "Authorization:Basic $BB_API_TOKEN" --url "$BRANCH_RESTRICTION_URL/$branch_restriction_id"
				done
				# Merge PRs from dev to release/FIRST_UNRELEASED_VERSION in all the repositories
				merge_pull_request $REPO_BASE_URL $PR_ID
			else
				echo "PR: $PR_ID is not from dev to release branch."
				merge_pull_request $REPO_BASE_URL $PR_ID
			fi
		done

		if [[ "$branch_restrictions_removed" == true ]]; then
			#Re-Add Branch Restrictions
			echo "Re-Adding Branch Restrictions on the release/$FIRST_UNRELEASED_VERSION branch in $repo."
			apply_branch_restrictions $repo
		fi
	done
	



else
    echo "Not all tickets are in Deployment Status"
fi
