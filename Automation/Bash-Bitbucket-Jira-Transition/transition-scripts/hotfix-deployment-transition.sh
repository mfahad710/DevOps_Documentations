#!/bin/bash

# Verify all the issues with the status "Deployment" have a fixVersion(released version).
# Get the Open PRs from Stage to Prod and Dev in all the repositories
# Check the approval status of the PRs and merge them if approved
# If not approved, then revert the DevOps transition and exit the script
# Create PRs from dev to release/FIRST_UNRELEASED_VERSION in all the repositories

# Get the issues in the "Deployment" status with the fixVersion in the released versions
JQL_QUERY='status = "Deployment" AND fixVersion in releasedVersions()'
# URL-encode the JQL query
ENCODED_JQL_QUERY=$(echo "$JQL_QUERY" | jq -sRr @uri)

ISSUE_KEYS=$(curl --request GET --url "$JIRA_BASE_URL/rest/api/3/search?jql=$ENCODED_JQL_QUERY" --header "Accept: application/json" --header "Authorization: Basic $JIRA_API_TOKEN" | jq -r '.issues[].key')

echo -e "Hotfix Issues in Deployment status: \n"
echo -e "$ISSUE_KEYS"

if [ -z "$ISSUE_KEYS" ]; then
    echo "No hotfix issues found in Deployment status."
fi

# Initialize list of repository that has tickets in Deployment status
declare -a REPOSITORIES=()

# Loop through each issue to fetch its associated repository
for ISSUE_KEY in $ISSUE_KEYS; do
    # Fetch issue details
    ISSUE_DETAIL=$(curl --request GET --url "$JIRA_BASE_URL/rest/api/3/issue/$ISSUE_KEY" --header "Accept: application/json" --header "Authorization: Basic $JIRA_API_TOKEN")

    # Extract repository information
    REPOSITORY=$(echo "$ISSUE_DETAIL" | jq -r '.fields.customfield_10042.value')

    # Check if repository is not null and add to the array
    if [ "$REPOSITORY" != "null" ]; then
        REPOSITORIES+=("$REPOSITORY")
    else
        echo "No repository found for issue $ISSUE_KEY."
    fi
done

# Print repositories
echo -e "\nRepositories associated with the Hotfixes in Deployment status:"
echo "${REPOSITORIES[@]}"

# Declare the List of repositories
declare -a repos=("fort_backend" "fort_frontend" "fort_license")

# Global Variables to store the count of approved and merged pull requests for each repository
fort_backend_approved_status_count=0
fort_backend_merge_status_count=0
fort_frontend_approved_status_count=0
fort_frontend_merge_status_count=0
fort_license_approved_status_count=0
fort_license_merge_status_count=0


# merge_pull_request function to merge the PRs if approved
merge_pull_request(){
	local REPO_BASE_URL=$1
	local PR_ID=$2
    local -n ref_APPROVED_STATUS_COUNT=$3
    local -n ref_MERGED_STATUS_COUNT=$4

	echo "Processing pull request $PR_ID from $REPO_BASE_URL"

    ## Check approval status of the pull request all reviewers are required to approve
	APPROVAL_STATUS=$(curl -s -H "Authorization: Basic $BB_API_TOKEN" "$REPO_BASE_URL/pullrequests/$PR_ID" | jq -r '.participants | map(select(.role == "REVIEWER")) | all(.approved==true)')

    ## If any of reviewers approved the PR
	# APPROVAL_STATUS=$(curl -s -H "Authorization: Basic $BB_API_TOKEN" "$REPO_BASE_URL/pullrequests/$PR_ID" | jq -r '
	# 				  .participants | map(select(.role == "REVIEWER")) |
	# 		           any(.user.uuid == "{b55e5165-481g-4cc8-84a3-96c19de7d218}" and .approved == true) or
	# 		           any(.user.uuid == "{6e57cf78-4141-698d-959d-8f3e5e8995aa}" and .approved == true)')

	echo -e "Approval Status: $APPROVAL_STATUS\n"

	if [[ "$APPROVAL_STATUS" == "true" ]]; then
            ((ref_APPROVED_STATUS_COUNT++))
			echo "Merging pull request $PR_ID."
			MERGE_URL="$REPO_BASE_URL/pullrequests/$PR_ID/merge"
			MERGE_RESPONSE=$(curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" "$MERGE_URL")
			MERGE_STATUS=$(echo "$MERGE_RESPONSE" | jq -r '.state')

			echo "Merge status for the PR: $PR_ID is $MERGE_STATUS"

			if [[ "$MERGE_STATUS" == "MERGED" ]]; then
                    ((ref_MERGED_STATUS_COUNT++))
					echo "PR: $PR_ID Merged Successfully"
			else
					echo "Merge Conflicts for the PR: $PR_ID"
			fi
	else
            echo "PR: $PR_ID is not approved."
            revert_devops_transition
    fi

}

# Get the PRs with source branch as stage and target branch as prod in each repository
# Check the approval status of the PRs and merge them if approved
# If not approved, then revert the DevOps transition and exit the script
process_repository() {
	local repo=$1

    APPROVED_STATUS_COUNT=0
    MERGED_STATUS_COUNT=0

    echo "Repository: $repo"
    REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"

    OPEN_PROD_PR=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=10&state=OPEN" \
		--header "Authorization: Basic $BB_API_TOKEN" \
		| jq -r --arg ver "stage" '.values 
		| map(select(.source.branch.name == $ver and .destination.branch.name == "prod")) 
		| sort_by(.created_on) 
		| last')

	MERGED_PROD_PR=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=10&state=MERGED" \
		--header "Authorization: Basic $BB_API_TOKEN" \
		| jq -r --arg ver "stage" '.values 
		| map(select(.source.branch.name == $ver and .destination.branch.name == "prod")) 
		| sort_by(.created_on) 
		| last')

	if [[ $OPEN_PROD_PR != null ]]; then
		PROD_PR="$OPEN_PROD_PR"
	else 
		PROD_PR="$MERGED_PROD_PR"
    fi

	PROD_PR_ID=$(echo "$PROD_PR" | jq -s '.[] | .id')
	PROD_PR_STATE=$(echo "$PROD_PR" | jq -s '.[] | .state')

	PROD_PR_STATE=$(echo "$PROD_PR_STATE" | tr -d '"' | tr -d '[:space:]')

	echo "PROD PR ID: $PROD_PR_ID"
	echo "PROD PR Status: $PROD_PR_STATE"

	echo "Processing Stage --> Prod PR, ID: $PROD_PR_ID, State: $PROD_PR_STATE"
	if [[ "$PROD_PR_STATE" == "OPEN" ]]; then
		merge_pull_request $REPO_BASE_URL $PROD_PR_ID APPROVED_STATUS_COUNT MERGED_STATUS_COUNT
	elif [[ "$PROD_PR_STATE" == "MERGED" ]]; then
		((APPROVED_STATUS_COUNT++))
        ((MERGED_STATUS_COUNT++))
		echo "PR: $PROD_PR_ID is already Merged."
	fi

		
	OPEN_DEV_PR=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=10&state=OPEN" \
		--header "Authorization: Basic $BB_API_TOKEN" \
		| jq -r --arg ver "stage" '.values 
		| map(select(.source.branch.name == $ver and .destination.branch.name == "dev")) 
		| sort_by(.created_on) 
		| last')

	MERGED_DEV_PR=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=10&state=MERGED" \
		--header "Authorization: Basic $BB_API_TOKEN" \
		| jq -r --arg ver "stage" '.values 
		| map(select(.source.branch.name == $ver and .destination.branch.name == "dev")) 
		| sort_by(.created_on) 
		| last')

		
	if [[ $OPEN_DEV_PR != null ]]; then
		DEV_PR="$OPEN_DEV_PR"
	else
		DEV_PR="$MERGED_DEV_PR"
	fi


	DEV_PR_ID=$(echo "$DEV_PR" | jq -s '.[] | .id')
	DEV_PR_STATE=$(echo "$DEV_PR" | jq -s '.[] | .state')

	DEV_PR_STATE=$(echo "$DEV_PR_STATE" | tr -d '"' | tr -d '[:space:]')

	echo "Processing Stage --> Dev PR, ID: $DEV_PR_ID, State: $DEV_PR_STATE"
	if [[ "$DEV_PR_STATE" == "OPEN" ]]; then
		merge_pull_request $REPO_BASE_URL $DEV_PR_ID APPROVED_STATUS_COUNT MERGED_STATUS_COUNT
	elif [[ "$DEV_PR_STATE" == "MERGED" ]]; then
		((APPROVED_STATUS_COUNT++))
        ((MERGED_STATUS_COUNT++))
		echo "PR: $DEV_PR_ID is already Merged."
	fi

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

revert_devops_transition() {
	# Revert the DevOps transition from Deployment to Stage Testing
	echo "Reverting the transition"

	JQL_QUERY='issuetype=DevOps AND status = "Deployment" AND "Deployment\u007f[Dropdown]" = "Hotfix"'
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

# Create PRs from dev to release/FIRST_UNRELEASED_VERSION in all the repositories

create_pull_request(){
    local repo=$1

    echo "Creating PR from dev to release/$FIRST_UNRELEASED_VERSION in $repo"

    REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"
    PULL_REQUEST_URL="$REPO_BASE_URL/pullrequests"

    PULL_REQUEST_PAYLOAD="{\"title\": \"Pull Request for: Merge dev to release/$FIRST_UNRELEASED_VERSION\", \"source\": { \"branch\": { \"name\": \"dev\" } }, \"destination\": { \"branch\": { \"name\": \"release/$FIRST_UNRELEASED_VERSION\" } }, \"close_source_branch\": false }"

    CREATE_PR_RESPONSE=$(curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" -H "Content-Type: application/json" -d "$PULL_REQUEST_PAYLOAD" "$PULL_REQUEST_URL")
    PR_ID=$(echo "$CREATE_PR_RESPONSE" | jq -r '.id')

    echo "Pull Request ID: $PR_ID created successfully in $repo"
}

for repo in "${REPOSITORIES[@]}"; do
    process_repository $repo
done

if [[ $fort_backend_approved_status_count != $fort_backend_merge_status_count || $fort_frontend_approved_status_count != $fort_frontend_merge_status_count ||  $fort_license_approved_status_count != $fort_license_merge_status_count ]]; then
    echo "All PRs are merged successfully."

    # Create PRs from dev to release/FIRST_UNRELEASED_VERSION in all the repositories
    FIRST_UNRELEASED_VERSION=$(curl -s -H "Authorization:Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/project/FORT/versions" | jq -r '.[] | select(.released == false) | .name' | head -n 1)
    echo "Latest Version: $FIRST_UNRELEASED_VERSION"

    for repo in "${REPOSITORIES[@]}"; do
        create_pull_request $repo
    done

    echo "All PRs are merged successfully. PRs are created from dev to release/$FIRST_UNRELEASED_VERSION in all the repositories."

    echo "Deploy the Hotfixes build to the Production Environment manually."

    exit 0

else
    echo "All PRs are not merged successfully. Reverting the DevOps transition."
    revert_devops_transition
fi
