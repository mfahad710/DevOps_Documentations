#!/bin/bash

# Get the latest version from Jira
FIRST_UNRELEASED_VERSION=$(curl -s -H "Authorization:Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/project/FORT/versions" | jq -r '.[] | select(.released == false) | .name' | head -n 1)
echo "Merge PRs from stage to prod and dev for release/$FIRST_UNRELEASED_VERSION Pipeline running from Jira Automation."

# GET all related issues that are in "Deployment" status and have the latest version
ISSUE_KEYS=$(curl --request GET --url "$JIRA_BASE_URL/rest/api/3/search?jql=status=\"Deployment\"+AND+fixVersion=\"$FIRST_UNRELEASED_VERSION\"" --header "Accept: application/json" --header "Authorization: Basic $JIRA_API_TOKEN" | jq -r '.issues[].key')
echo "Issue key: $ISSUE_KEYS"

# Repositories array
declare -a repos=("fort_backend" "fort_frontend" "fort_license")

# The total number of repositories will be used to compare with the total number of merged PRs
# to decide whether to release the current version or revert the DevOps transition
# Total_Repos=${#repos[@]}
# echo "Total Repos: $Total_Repos"

Repos_with_OPEN_PRs=()

Total_OPEN_PRs=0
Total_Merged_PRs=0

for repo in ${repos[@]}; do
	REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"

	OPEN_PROD_PR_Count=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50&state=OPEN" \
		--header "Authorization: Basic $BB_API_TOKEN" \
		| jq '[.values[] | select(.source.branch.name == "stage" and .destination.branch.name == "prod")] | length')
	echo "Open stage to prod PR Count in ${repo} is: ${OPEN_PROD_PR_Count}"

	OPEN_DEV_PR_Count=$(curl -s --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50&state=OPEN" \
		--header "Authorization: Basic $BB_API_TOKEN" \
		| jq '[.values[] | select(.source.branch.name == "stage" and .destination.branch.name == "dev")] | length')
	echo "Open stage to dev PR Count in ${repo} is: ${OPEN_DEV_PR_Count}"

	Total_OPEN_PRs=$((Total_OPEN_PRs + OPEN_PROD_PR_Count + OPEN_DEV_PR_Count))

	# Check if both PRs exist
	if [[ $OPEN_PROD_PR_Count -gt 0 && $OPEN_DEV_PR_Count -gt 0 ]]; then
		Repos_with_OPEN_PRs+=($repo)
		echo "Repository $repo has both stage-to-prod and stage-to-dev PRs."
	else
		echo "Repository $repo does not have both stage-to-prod and stage-to-dev PRs."
	fi

done

echo "Number of open PRs: $Total_OPEN_PRs"
Expected_Merged_PRs=$((Total_OPEN_PRs))

echo "List of repositories that has OPEN stage to prod and stage to dev PRs: ${Repos_with_OPEN_PRs[@]}"

# merge_pull_request function to merge the PRs if approved
merge_pull_request(){
	local REPO_BASE_URL=$1
	local PR_ID=$2

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

			echo "Merging pull request $PR_ID."
			MERGE_URL="$REPO_BASE_URL/pullrequests/$PR_ID/merge"
			MERGE_RESPONSE=$(curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" "$MERGE_URL")
			MERGE_STATUS=$(echo "$MERGE_RESPONSE" | jq -r '.state')

			echo "Merge status for the PR: $PR_ID is $MERGE_STATUS"

			if [[ "$MERGE_STATUS" == "MERGED" ]]; then
					((Total_Merged_PRs++))
					echo "Total Merged PRs: $Total_Merged_PRs"
					echo "PR: $PR_ID Merged Successfully"
			else
					echo "ERROR; PR Could not be Merged ---> ID: $PR_ID"
					echo "**********************************************"
					echo "*************MERGE RESPONSE*******************"
					echo $MERGE_RESPONSE
					echo "**********************************************"
			fi
	else
		echo "PR: $PR_ID is not approved."
		revert_devops_transition
	fi

}

# Get the PRs with source branch as stage and target branch as prod
# Check the approval status of the PRs and merge them if approved
# If not approved, then revert the DevOps transition and exit the script
process_repository() {
	local repo=$1

	
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
		merge_pull_request $REPO_BASE_URL $PROD_PR_ID
	elif [[ "$PROD_PR_STATE" == "MERGED" ]]; then
		((Total_Merged_PRs++))
		echo "PR: $PROD_PR_ID is already Merged."
		echo "Total Merged PRs: $Total_Merged_PRs"
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
		merge_pull_request $REPO_BASE_URL $DEV_PR_ID
	elif [[ "$DEV_PR_STATE" == "MERGED" ]]; then
		((Total_Merged_PRs++))
		echo "PR: $DEV_PR_ID is already Merged."
		echo "Total Merged PRs: $Total_Merged_PRs"
	fi
	   
}

revert_devops_transition() {
	# Revert the DevOps transition from Deployment to Stage Testing
	echo "Reverting the transition"

	JQL_QUERY='issuetype=DevOps AND status = "Deployment" AND "Deployment\u007f[Dropdown]" = "Release"'
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

create_pull_request(){
	# Create PRs, dev to branch for all the PRs with destination branch as release/Released_Version
	local destBranch=$1
    PR_PAYLOAD="{\"title\": \"Pull request for: Merge dev to $destBranch\", \"source\": {\"branch\": {\"name\": \"dev\"}}, \"destination\": {\"branch\": {\"name\": \"$destBranch\"}}, \"description\": \"Created by BitBucket REST API\", \"close_source_branch\": false}"
    # Create and display the response
    RESPONSE=$(curl -X POST "$REPO_BASE_URL/pullrequests/" -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$PR_PAYLOAD")
    echo "PR Created Successfully in $REPO. with Pull Request ID:"	
    echo "$RESPONSE" | jq '.id'
}

# Function to apply branch restrictions on the release branch
apply_branch_restrictions(){
    local REPO=$1
	local RELEASE_VERSION=$2
    # Restrict the current release branch in all repos.
    REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$REPO"
    BRANCH_PATTERN="release/$RELEASE_VERSION"
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

# *******************************************************************************
# *******************************************************************************

# Merge PRs(if approved) from stage to prod and dev
for repo in "${Repos_with_OPEN_PRs[@]}"; do
	process_repository $repo Total_Merged_PRs
done

# *******************************************************************************
# *******************************************************************************

# If PRs are approved and merged successfully, and all the issues with the Latest version are in Deployment status
# then release the current version and create branches for the new version in specific repository
# and update the PRs from old version to new version in all the repositories
# else revert the DevOps transition from Deployment to Stage Testing
# and exit the script

if [[ "$Total_Merged_PRs" == "$Expected_Merged_PRs" ]]; then

	echo -e "All PRs are merged successfully.\n"
	echo -e "Expected Merged PRs: $Expected_Merged_PRs \n"
	echo -e "Total Merged PRs: $Total_Merged_PRs \n"

	JQL_RESPONSE=$(curl --request GET --url "$JIRA_BASE_URL/rest/api/2/search?jql=fixVersion=\"$FIRST_UNRELEASED_VERSION\"+AND+status!=\"Deployment\"" --header "Authorization: Basic $JIRA_API_TOKEN")
	ISSUE_COUNT=$(echo "$JQL_RESPONSE" | jq '.total')
	echo "Number of issues: $ISSUE_COUNT"

	# if there are not any issues which have the fix version as the latest version and not in Deployment status
	# it means all the issues with the latest version as fix version are in Deployment status

	if [[ "$ISSUE_COUNT" == 0 ]]; then
		echo "All the tickets of the Current Version $FIRST_UNRELEASED_VERSION are in Deployment Status"

		VERSION_ID=$(curl -s -H "Authorization:Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/project/FORT/versions" | jq -r '.[] | select(.released == false) | .id' | head -n 1)
		echo "version id: $VERSION_ID"

		# Release the current version.
		RELEASE_VERSION_URL="$JIRA_BASE_URL/rest/api/3/version/$VERSION_ID"
		RELEASE_PAYLOAD="{\"id\": \"$VERSION_ID\", \"name\":\"$FIRST_UNRELEASED_VERSION\", \"released\": true}"
		RELEASE_RESPONSE=$(curl --request PUT --url "$RELEASE_VERSION_URL" -H "Authorization:Basic $JIRA_API_TOKEN" -H "Content-Type:application/json" -H "Accept:application/json" -d "$RELEASE_PAYLOAD" )
		echo "Release response: $RELEASE_RESPONSE"

		RELEASE_STATUS=$(echo "$RELEASE_RESPONSE" | jq -r '.released')
		echo "Status of current release: $RELEASE_STATUS"

		if [[ "$RELEASE_STATUS" == true ]]; then
			echo "The Current version $FIRST_UNRELEASED_VERSION has been released"

			RELEASED_VERSION=$(curl -s -H "Authorization:Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/project/FORT/versions" | jq -r '.[] | select(.released == true) | .name' | tail -n 1)
			echo "Released Version: $RELEASED_VERSION"

			NEW_RELEASE_VERSION=$(curl -s -H "Authorization:Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/project/FORT/versions" | jq -r '.[] | select(.released == false) | .name' | head -n 1)
			echo "New or Latest Version: $NEW_RELEASE_VERSION"

			# Create the branches for the new version in all the repositories

			for repo in "${repos[@]}"; do
				REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"
				NEW_BRANCH_NAME="release/$NEW_RELEASE_VERSION"
				NEW_BRANCH_URL="$REPO_BASE_URL/refs/branches"
				NEW_BRANCH_PAYLOAD="{\"name\": \"$NEW_BRANCH_NAME\", \"target\": {\"hash\": \"dev\"}}"
				NEW_BRANCH_RESPONSE=$(curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" -H "Content-Type: application/json" -d "$NEW_BRANCH_PAYLOAD" "$NEW_BRANCH_URL")
				echo "New Branch Response: $NEW_BRANCH_RESPONSE"
			done

			#Get Open PRs with destination branch as release/Released_Version in each repository
			for repo in "${repos[@]}"; do
				REPO_BASE_URL="https://api.bitbucket.org/2.0/repositories/fort/$repo"
				OPEN_RELEASE_PRS=$(curl --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.destination.branch.name == \"release/$RELEASED_VERSION\") | .id")
				OPEN_HOTFIX_PRS=$(curl --request GET --url "$REPO_BASE_URL/pullrequests?pagelen=50" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.source.branch.name | startswith(\"hotfix/\")) | .id")
				# get branch names of all the Open PRs with destination branch as release/Released_Version
				for PR_ID in $OPEN_RELEASE_PRS; do
					PR_SOURCE_BRANCH=$(curl --request GET --url "$REPO_BASE_URL/pullrequests/$PR_ID" --header "Authorization: Basic $BB_API_TOKEN" | jq -r '.source.branch.name')
					echo "PR_ID: $PR_ID; PR_SOURCE_BRANCH: $PR_SOURCE_BRANCH"
					# Create PRs, dev to branch for all the PRs with destination branch as release/Released_Version
					create_pull_request $PR_SOURCE_BRANCH
				done

				for PR_ID in $OPEN_HOTFIX_PRS; do
					PR_SOURCE_BRANCH=$(curl --request GET --url "$REPO_BASE_URL/pullrequests/$PR_ID" --header "Authorization: Basic $BB_API_TOKEN" | jq -r '.source.branch.name')
					echo "PR_ID: $PR_ID; PR_SOURCE_BRANCH: $PR_SOURCE_BRANCH"
					# Create PRs, dev to branch for all the PRs with source branch as hotfix/
					create_pull_request $PR_SOURCE_BRANCH
				done

				# Update Pull Requests from old version to new version in all the repositories
				for PR_ID in $OPEN_RELEASE_PRS; do
					UPDATE_PR_URL="$REPO_BASE_URL/pullrequests/$PR_ID"
					UPDATE_PR_PAYLOAD="{\"destination\": {\"branch\": {\"name\": \"release/$NEW_RELEASE_VERSION\"}}}"
					UPDATE_PR_RESPONSE=$(curl -s -X PUT -H "Authorization: Basic $BB_API_TOKEN" -H "Content-Type: application/json" -d "$UPDATE_PR_PAYLOAD" "$UPDATE_PR_URL")
					UPDATE_PR_STATUS=$(echo "$UPDATE_PR_RESPONSE" | jq -r '.destination.branch.name') 
					echo "Destination for Pull request $PR_ID is now $UPDATE_PR_STATUS"
				done

				apply_branch_restrictions $repo $NEW_RELEASE_VERSION

			done

		else
			echo "The Current version $FIRST_UNRELEASED_VERSION has not been released"
		fi

	else
		echo "Not all issues are in Deployment status."
		# Revert the DevOps transition from Deployment to Stage Testing
		revert_devops_transition
	fi

else
	echo "Not all PRs are merged successfully."
	# Revert the DevOps transition from Deployment to Stage Testing
	revert_devops_transition
fi
