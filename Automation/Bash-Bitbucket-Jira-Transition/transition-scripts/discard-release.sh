#!/bin/bash

# Get the current version to be discarded.
LATEST_VERSION=$(curl -s -H "Authorization:Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/project/FORT/versions" | jq -r '.[] | select(.released == false) | .name' | head -n 1)
echo "Version to be discarded: $LATEST_VERSION"

# Restrict the current release branch in all repos.
BRANCH_PATTERN="release/$LATEST_VERSION"
echo "Restricting the branch: $BRANCH_PATTERN."
RESTRICTION_TYPES=("push" "restrict_merges" "force" "delete")

# BACKEND
BACKEND_BRANCH_RESTRICTION_URL="$BB_BACKEND_URL/branch-restrictions"
# Iterate over the restriction types and create branch restrictions
for restriction_type in "${RESTRICTION_TYPES[@]}"; do
    echo -e "Adding restriction: $restriction_type on branch $BRANCH_PATTERN.\n"
    BRANCH_RESTRICTION_PAYLOAD="{\"kind\": \"$restriction_type\", \"type\": \"branchrestriction\", \"pattern\": \"$BRANCH_PATTERN\", \"users\": [], \"groups\": []}"
    curl -s -X POST  -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$BRANCH_RESTRICTION_PAYLOAD"  --url "$BACKEND_BRANCH_RESTRICTION_URL"

done

# ADMIN
ADMIN_BRANCH_RESTRICTION_URL="$BB_ADMIN_URL/branch-restrictions"
# Iterate over the restriction types and create branch restrictions
for restriction_type in "${RESTRICTION_TYPES[@]}"; do
    echo -e "Adding restriction: $restriction_type on branch $BRANCH_PATTERN.\n"
    BRANCH_RESTRICTION_PAYLOAD="{\"kind\": \"$restriction_type\", \"type\": \"branchrestriction\", \"pattern\": \"$BRANCH_PATTERN\", \"users\": [], \"groups\": []}"
    curl -s -X POST  -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$BRANCH_RESTRICTION_PAYLOAD"  --url "$ADMIN_BRANCH_RESTRICTION_URL"

done

# FRONTEND
FRONTEND_BRANCH_RESTRICTION_URL="$BB_FRONTEND_URL/branch-restrictions"
# Iterate over the restriction types and create branch restrictions
for restriction_type in "${RESTRICTION_TYPES[@]}"; do
    echo -e "Adding restriction: $restriction_type on branch $BRANCH_PATTERN.\n"
    BRANCH_RESTRICTION_PAYLOAD="{\"kind\": \"$restriction_type\", \"type\": \"branchrestriction\", \"pattern\": \"$BRANCH_PATTERN\", \"users\": [], \"groups\": []}"
    curl -s -X POST  -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$BRANCH_RESTRICTION_PAYLOAD"  --url "$FRONTEND_BRANCH_RESTRICTION_URL"

done


# LICENSE BACKEND
LICENSE_BACKEND_BRANCH_RESTRICTION_URL="$BB_LICENSE_BACKEND_URL/branch-restrictions"
# Iterate over the restriction types and create branch restrictions
for restriction_type in "${RESTRICTION_TYPES[@]}"; do
    echo -e "Adding restriction: $restriction_type on branch $BRANCH_PATTERN.\n"
    BRANCH_RESTRICTION_PAYLOAD="{\"kind\": \"$restriction_type\", \"type\": \"branchrestriction\", \"pattern\": \"$BRANCH_PATTERN\", \"users\": [], \"groups\": []}"
    curl -s -X POST  -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$BRANCH_RESTRICTION_PAYLOAD"  --url "$LICENSE_BACKEND_BRANCH_RESTRICTION_URL"

done


# LICENSE FRONTEND
LICENSE_FRONTEND_BRANCH_RESTRICTION_URL="$BB_LICENSE_FRONTEND_URL/branch-restrictions"
# Iterate over the restriction types and create branch restrictions
for restriction_type in "${RESTRICTION_TYPES[@]}"; do
    echo -e "Adding restriction: $restriction_type on branch $BRANCH_PATTERN.\n"
    BRANCH_RESTRICTION_PAYLOAD="{\"kind\": \"$restriction_type\", \"type\": \"branchrestriction\", \"pattern\": \"$BRANCH_PATTERN\", \"users\": [], \"groups\": []}"
    curl -s -X POST  -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$BRANCH_RESTRICTION_PAYLOAD"  --url "$LICENSE_FRONTEND_BRANCH_RESTRICTION_URL"

done

# Transition the current version tickets to release deployment from anywhere.
ISSUES=$(curl --request GET --url "$JIRA_BASE_URL/rest/api/3/search?jql=fixVersion=\"$LATEST_VERSION\"" -H "Accept: application/json" -H "Authorization: Basic $JIRA_API_TOKEN")
issue_info=$(echo "$ISSUES" | jq -r '.issues[] | .fields.assignee.displayName, .key, .fields.summary')

ISSUE_KEYS=$(curl --request GET --url "$JIRA_BASE_URL/rest/api/3/search?jql=fixVersion=\"$LATEST_VERSION\"" -H "Accept: application/json" -H "Authorization: Basic $JIRA_API_TOKEN" | jq -r '.issues[].key')
echo -e "Transitioning tickets to Release Deployment. \n"
for ISSUE_KEY in $ISSUE_KEYS; do
        # Transition the issue
        TRANSITION_URL="$JIRA_BASE_URL/rest/api/2/issue/$ISSUE_KEY/transitions/"
        TRANSITION_PAYLOAD="{\"transition\": { \"id\": \"$TRANSITION_ID\" } }"
        curl -X POST -H "Authorization:Basic $JIRA_API_TOKEN" -H "Content-Type:application/json" -d "$TRANSITION_PAYLOAD" "$TRANSITION_URL"
done


# Decline the PRs from release to prod and release to dev

# BACKEND
# Release to Prod Open pull request. 
echo "Declining PRs from release to prod and release to dev."
BACKEND_PROD_PR_ID=$(curl --request GET --url "$BB_BACKEND_URL/pullrequests?pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.source.branch.name == \"release/$LATEST_VERSION\" and .destination.branch.name == \"$PROD_BRANCH\") | .id")
BACKEND_PROD_DECLINE_URL="$BB_BACKEND_URL/pullrequests/$BACKEND_PROD_PR_ID/decline"

curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H "Accept: application/json" "$BACKEND_PROD_DECLINE_URL"

# Release to dev Open pull request. 
BACKEND_DEV_PR_ID=$(curl --request GET --url "$BB_BACKEND_URL/pullrequests?pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.source.branch.name == \"release/$LATEST_VERSION\" and .destination.branch.name == \"$DEV_BRANCH\") | .id")
BACKEND_DEV_DECLINE_URL="$BB_BACKEND_URL/pullrequests/$BACKEND_DEV_PR_ID/decline"

curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H "Accept: application/json" "$BACKEND_DEV_DECLINE_URL"

# ADMIN
# Release to Prod Open pull request. 
ADMIN_PROD_PR_ID=$(curl --request GET --url "$BB_ADMIN_URL/pullrequests?pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.source.branch.name == \"release/$LATEST_VERSION\" and .destination.branch.name == \"$PROD_BRANCH\") | .id")
ADMIN_PROD_DECLINE_URL="$BB_ADMIN_URL/pullrequests/$ADMIN_PROD_PR_ID/decline"

curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H "Accept: application/json" "$ADMIN_PROD_DECLINE_URL"

# Release to dev Open pull request. 
ADMIN_DEV_PR_ID=$(curl --request GET --url "$BB_ADMIN_URL/pullrequests?pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.source.branch.name == \"release/$LATEST_VERSION\" and .destination.branch.name == \"$DEV_BRANCH\") | .id")
ADMIN_DEV_DECLINE_URL="$BB_ADMIN_URL/pullrequests/$ADMIN_DEV_PR_ID/decline"

curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H "Accept: application/json" "$ADMIN_DEV_DECLINE_URL"

# FRONTEND
# Release to Prod Open pull request. 
FRONTEND_PROD_PR_ID=$(curl --request GET --url "$BB_FRONTEND_URL/pullrequests?pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.source.branch.name == \"release/$LATEST_VERSION\" and .destination.branch.name == \"$PROD_BRANCH\") | .id")
FRONTEND_PROD_DECLINE_URL="$BB_FRONTEND_URL/pullrequests/$FRONTEND_PROD_PR_ID/decline"

curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H "Accept: application/json" "$FRONTEND_PROD_DECLINE_URL"

# Release to dev Open pull request. 
FRONTEND_DEV_PR_ID=$(curl --request GET --url "$BB_FRONTEND_URL/pullrequests?pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.source.branch.name == \"release/$LATEST_VERSION\" and .destination.branch.name == \"$DEV_BRANCH\") | .id")
FRONTEND_DEV_DECLINE_URL="$BB_FRONTEND_URL/pullrequests/$FRONTEND_DEV_PR_ID/decline"

curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H "Accept: application/json" "$FRONTEND_DEV_DECLINE_URL"


# LICENSE BACKEND
# Release to Prod Open pull request. 
LICENSE_BACKEND_PROD_PR_ID=$(curl --request GET --url "$BB_LICENSE_BACKEND_URL/pullrequests?pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.source.branch.name == \"release/$LATEST_VERSION\" and .destination.branch.name == \"$PROD_BRANCH\") | .id")
LICENSE_BACKEND_PROD_DECLINE_URL="$BB_LICENSE_BACKEND_URL/pullrequests/$LICENSE_BACKEND_PROD_PR_ID/decline"

curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H "Accept: application/json" "$LICENSE_BACKEND_PROD_DECLINE_URL"

# Release to dev Open pull request. 
LICENSE_BACKEND_DEV_PR_ID=$(curl --request GET --url "$BB_LICENSE_BACKEND_URL/pullrequests?pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.source.branch.name == \"release/$LATEST_VERSION\" and .destination.branch.name == \"$DEV_BRANCH\") | .id")
LICENSE_BACKEND_DEV_DECLINE_URL="$BB_LICENSE_BACKEND_URL/pullrequests/$LICENSE_BACKEND_DEV_PR_ID/decline"

curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H "Accept: application/json" "$LICENSE_BACKEND_DEV_DECLINE_URL"


# LICENSE FRONTEND
# Release to Prod Open pull request. 
LICENSE_FRONTEND_PROD_PR_ID=$(curl --request GET --url "$BB_LICENSE_FRONTEND_URL/pullrequests?pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.source.branch.name == \"release/$LATEST_VERSION\" and .destination.branch.name == \"$PROD_BRANCH\") | .id")
LICENSE_FRONTEND_PROD_DECLINE_URL="$BB_LICENSE_FRONTEND_URL/pullrequests/$LICENSE_FRONTEND_PROD_PR_ID/decline"

curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H "Accept: application/json" "$LICENSE_FRONTEND_PROD_DECLINE_URL"

# Release to dev Open pull request. 
LICENSE_FRONTEND_DEV_PR_ID=$(curl --request GET --url "$BB_LICENSE_FRONTEND_URL/pullrequests?pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.source.branch.name == \"release/$LATEST_VERSION\" and .destination.branch.name == \"$DEV_BRANCH\") | .id")
LICENSE_FRONTEND_DEV_DECLINE_URL="$BB_LICENSE_FRONTEND_URL/pullrequests/$LICENSE_FRONTEND_DEV_PR_ID/decline"

curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H "Accept: application/json" "$LICENSE_FRONTEND_DEV_DECLINE_URL"


# Getting the branches.
BACKEND_BRANCHES=$(curl -s --request GET --url "$BB_BACKEND_URL/pullrequests?state=MERGED&pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.destination.branch.name == \"release/$LATEST_VERSION\") | .source.branch.name")

ISSUE_KEYS=($ISSUE_KEYS)
BACKEND_BRANCH_NAMES=()

# Iterate over the branch names
for branch in $BACKEND_BRANCHES; do
    # Iterate over the issue keys
    for issue_key in "${ISSUE_KEYS[@]}"; do
        # Check if the branch name contains the issue key
        if [[ $branch == *"$issue_key"* ]]; then
            BACKEND_BRANCH_NAMES+=("$branch")
            break  # Stop iterating further if a match is found
        fi
    done
done

ADMIN_BRANCHES=$(curl -s --request GET --url "$BB_ADMIN_URL/pullrequests?state=MERGED&pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.destination.branch.name == \"release/$LATEST_VERSION\") | .source.branch.name")

ISSUE_KEYS=($ISSUE_KEYS)
ADMIN_BRANCH_NAMES=()

# Iterate over the branch names
for branch in $ADMIN_BRANCHES; do
    # Iterate over the issue keys
    for issue_key in "${ISSUE_KEYS[@]}"; do
        # Check if the branch name contains the issue key
        if [[ $branch == *"$issue_key"* ]]; then
            ADMIN_BRANCH_NAMES+=("$branch")
            break  # Stop iterating further if a match is found
        fi
    done
done


FRONTEND_BRANCHES=$(curl -s --request GET --url "$BB_FRONTEND_URL/pullrequests?state=MERGED&pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.destination.branch.name == \"release/$LATEST_VERSION\") | .source.branch.name")

ISSUE_KEYS=($ISSUE_KEYS)
FRONTEND_BRANCH_NAMES=()

# Iterate over the branch names
for branch in $FRONTEND_BRANCHES; do
    # Iterate over the issue keys
    for issue_key in "${ISSUE_KEYS[@]}"; do
        # Check if the branch name contains the issue key
        if [[ $branch == *"$issue_key"* ]]; then
            FRONTEND_BRANCH_NAMES+=("$branch")
            break  # Stop iterating further if a match is found
        fi
    done
done



LICENSE_BACKEND_BRANCHES=$(curl -s --request GET --url "$BB_LICENSE_BACKEND_URL/pullrequests?state=MERGED&pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.destination.branch.name == \"release/$LATEST_VERSION\") | .source.branch.name")

ISSUE_KEYS=($ISSUE_KEYS)
LICENSE_BACKEND_BRANCH_NAMES=()

# Iterate over the branch names
for branch in $LICENSE_BACKEND_BRANCHES; do
    # Iterate over the issue keys
    for issue_key in "${ISSUE_KEYS[@]}"; do
        # Check if the branch name contains the issue key
        if [[ $branch == *"$issue_key"* ]]; then
            LICENSE_BACKEND_BRANCH_NAMES+=("$branch")
            break  # Stop iterating further if a match is found
        fi
    done
done


LICENSE_FRONTEND_BRANCHES=$(curl -s --request GET --url "$BB_LICENSE_FRONTEND_URL/pullrequests?state=MERGED&pagelen=30" --header "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.destination.branch.name == \"release/$LATEST_VERSION\") | .source.branch.name")

ISSUE_KEYS=($ISSUE_KEYS)
LICENSE_FRONTEND_BRANCH_NAMES=()

# Iterate over the branch names
for branch in $LICENSE_FRONTEND_BRANCHES; do
    # Iterate over the issue keys
    for issue_key in "${ISSUE_KEYS[@]}"; do
        # Check if the branch name contains the issue key
        if [[ $branch == *"$issue_key"* ]]; then
            LICENSE_FRONTEND_BRANCH_NAMES+=("$branch")
            break  # Stop iterating further if a match is found
        fi
    done
done


# Archive/Delete the release branch to be discarded
VERSION_URL="$JIRA_BASE_URL/rest/api/2/project/FORT/versions"
# Get the version ID

VERSION_ID=$(curl -s -H "Authorization:Basic $JIRA_API_TOKEN" -H "Content-Type: application/json" -X GET "$VERSION_URL" | jq -r "map(select(.name == \"$LATEST_VERSION\")) | .[].id")
echo "Version id: $VERSION_ID"

# Archive the version
# ARCHIVE_URL="$JIRA_BASE_URL/rest/api/3/version/$VERSION_ID"
# curl -s -X PUT -H "Authorization:Basic $JIRA_API_TOKEN" -H "Content-Type: application/json" -d "{\"archived\": true}" "$ARCHIVE_URL"

# Delete the version
DELETE_URL="$JIRA_BASE_URL/rest/api/3/version/$VERSION_ID"
curl -s -X DELETE -H "Authorization:Basic $JIRA_API_TOKEN" "$DELETE_URL"


# Get the current version.
NEW_RELEASE_VERSION=$(curl -s -H "Authorization:Basic $JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/2/project/FORT/versions" | jq -r '.[] | select(.released == false) | .name' | head -n 1)
echo "Version: $NEW_RELEASE_VERSION"

# Create New Release Branch.

# Backend
BACKEND_RELEASE_BRANCH_PAYLOAD="{\"name\": \"release/$NEW_RELEASE_VERSION\", \"target\": {\"hash\": \"dev\"}}"
BACKEND_RELEASE_BRANCH_URL="$BB_BACKEND_URL/refs/branches"
curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" -H "Content-Type: application/json" -d "$BACKEND_RELEASE_BRANCH_PAYLOAD" "$BACKEND_RELEASE_BRANCH_URL"

# ADMIN
ADMIN_RELEASE_BRANCH_PAYLOAD="{\"name\": \"release/$NEW_RELEASE_VERSION\", \"target\": {\"hash\": \"dev\"}}"
ADMIN_RELEASE_BRANCH_URL="$BB_ADMIN_URL/refs/branches"
curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" -H "Content-Type: application/json" -d "$ADMIN_RELEASE_BRANCH_PAYLOAD" "$ADMIN_RELEASE_BRANCH_URL"

# FRONTEND
FRONTEND_RELEASE_BRANCH_PAYLOAD="{\"name\": \"release/$NEW_RELEASE_VERSION\", \"target\": {\"hash\": \"dev\"}}"
FRONTEND_RELEASE_BRANCH_URL="$BB_FRONTEND_URL/refs/branches"
curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" -H "Content-Type: application/json" -d "$FRONTEND_RELEASE_BRANCH_PAYLOAD" "$FRONTEND_RELEASE_BRANCH_URL"


# LICENSE BACKEND
LICENSE_BACKEND_RELEASE_BRANCH_PAYLOAD="{\"name\": \"release/$NEW_RELEASE_VERSION\", \"target\": {\"hash\": \"dev\"}}"
LICENSE_BACKEND_RELEASE_BRANCH_URL="$BB_LICENSE_BACKEND_URL/refs/branches"
curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" -H "Content-Type: application/json" -d "$LICENSE_BACKEND_RELEASE_BRANCH_PAYLOAD" "$LICENSE_BACKEND_RELEASE_BRANCH_URL"


# LICENSE FRONTEND
LICENSE_FRONTEND_RELEASE_BRANCH_PAYLOAD="{\"name\": \"release/$NEW_RELEASE_VERSION\", \"target\": {\"hash\": \"dev\"}}"
LICENSE_FRONTEND_RELEASE_BRANCH_URL="$BB_LICENSE_FRONTEND_URL/refs/branches"
curl -s -X POST -H "Authorization: Basic $BB_API_TOKEN" -H "Content-Type: application/json" -d "$LICENSE_FRONTEND_RELEASE_BRANCH_PAYLOAD" "$LICENSE_FRONTEND_RELEASE_BRANCH_URL"



# Update pull requests from old version to new version. 
BACKEND_RELEASED_PR_ID=$(curl --request GET --url "$BB_BACKEND_URL/pullrequests?pagelen=30" -H "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.destination.branch.name == \"release/$RELEASED_VERSION\") | .id")
echo "Released PRs: $BACKEND_RELEASED_PR_ID"
for PR_ID in $BACKEND_RELEASED_PR_ID; do
        # Update the pull request here.
        echo "Updating the pull request for $PR_ID."
        UPDATE_URL="$BB_BACKEND_URL/pullrequests/$PR_ID"
        UPDATE_PAYLOAD="{\"destination\": {\"branch\": {\"name\": \"release/$NEW_RELEASE_VERSION\"}}}"

        UPDATE_RESPONSE=$(curl -s -X PUT -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$UPDATE_PAYLOAD" "$UPDATE_URL")
        # Check for merge status for merge conflicts
        UPDATE_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r '.destination.branch.name') 
        echo "Destination for Pull request $PR_ID is now $UPDATE_STATUS"

done


# Update pull requests from old version to new version. 
FRONTEND_RELEASED_PR_ID=$(curl --request GET --url "$BB_FRONTEND_URL/pullrequests?pagelen=30" -H "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.destination.branch.name == \"release/$RELEASED_VERSION\") | .id")
echo "Released PRs: $FRONTEND_RELEASED_PR_ID"
for PR_ID in $FRONTEND_RELEASED_PR_ID; do
        # Update the pull request here.
        echo "Updating the pull request for $PR_ID."
        UPDATE_URL="$BB_FRONTEND_URL/pullrequests/$PR_ID"
        UPDATE_PAYLOAD="{\"destination\": {\"branch\": {\"name\": \"release/$NEW_RELEASE_VERSION\"}}}"

        UPDATE_RESPONSE=$(curl -s -X PUT -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$UPDATE_PAYLOAD" "$UPDATE_URL")
        # Check for merge status for merge conflicts
        UPDATE_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r '.destination.branch.name') 
        echo "Destination for Pull request $PR_ID is now $UPDATE_STATUS"

done


# Update pull requests from old version to new version. 
ADMIN_RELEASED_PR_ID=$(curl --request GET --url "$BB_ADMIN_URL/pullrequests?pagelen=30" -H "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.destination.branch.name == \"release/$RELEASED_VERSION\") | .id")
echo "Released PRs: $ADMIN_RELEASED_PR_ID"
for PR_ID in $ADMIN_RELEASED_PR_ID; do
        # Update the pull request here.
        echo "Updating the pull request for $PR_ID."
        UPDATE_URL="$BB_ADMIN_URL/pullrequests/$PR_ID"
        UPDATE_PAYLOAD="{\"destination\": {\"branch\": {\"name\": \"release/$NEW_RELEASE_VERSION\"}}}"

        UPDATE_RESPONSE=$(curl -s -X PUT -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$UPDATE_PAYLOAD" "$UPDATE_URL")
        UPDATE_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r '.destination.branch.name') 
        echo "Destination for Pull request $PR_ID is now $UPDATE_STATUS"

done


# Update pull requests from old version to new version. 
LICENSE_BACKEND_RELEASED_PR_ID=$(curl --request GET --url "$BB_LICENSE_BACKEND_URL/pullrequests?pagelen=30" -H "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.destination.branch.name == \"release/$RELEASED_VERSION\") | .id")
echo "Released PRs: $LICENSE_BACKEND_RELEASED_PR_ID"
for PR_ID in $LICENSE_BACKEND_RELEASED_PR_ID; do
        # Update the pull request here.
        echo "Updating the pull request for $PR_ID."
        UPDATE_URL="$BB_LICENSE_BACKEND_URL/pullrequests/$PR_ID"
        UPDATE_PAYLOAD="{\"destination\": {\"branch\": {\"name\": \"release/$NEW_RELEASE_VERSION\"}}}"

        UPDATE_RESPONSE=$(curl -s -X PUT -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$UPDATE_PAYLOAD" "$UPDATE_URL")
        UPDATE_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r '.destination.branch.name') 
        echo "Destination for Pull request $PR_ID is now $UPDATE_STATUS"

done

# Update pull requests from old version to new version. 
LICENSE_FRONTEND_RELEASED_PR_ID=$(curl --request GET --url "$BB_LICENSE_FRONTEND_URL/pullrequests?pagelen=30" -H "Authorization: Basic $BB_API_TOKEN" | jq -r ".values[] | select(.destination.branch.name == \"release/$RELEASED_VERSION\") | .id")
echo "Released PRs: $LICENSE_FRONTEND_RELEASED_PR_ID"
for PR_ID in $LICENSE_FRONTEND_RELEASED_PR_ID; do
        # Update the pull request here.
        echo "Updating the pull request for $PR_ID."
        UPDATE_URL="$BB_LICENSE_FRONTEND_URL/pullrequests/$PR_ID"
        UPDATE_PAYLOAD="{\"destination\": {\"branch\": {\"name\": \"release/$NEW_RELEASE_VERSION\"}}}"

        UPDATE_RESPONSE=$(curl -s -X PUT -H "Authorization:Basic $BB_API_TOKEN" -H "Content-Type:application/json" -d "$UPDATE_PAYLOAD" "$UPDATE_URL")
        UPDATE_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r '.destination.branch.name') 
        echo "Destination for Pull request $PR_ID is now $UPDATE_STATUS"

done



# Create pull reqeusts from the source branch to new release branch
# BACKEND
for branch in "${BACKEND_BRANCH_NAMES[@]}"; do
    echo -e "PR from $branch to release/$NEW_RELEASE_VERSION. \n"
    while read -r ISSUE_ASSIGNEE_NAME && read -r ISSUE_KEY && read -r ISSUE_SUMMARY; do
        CREATE_PR_PAYLOAD="{\"title\": \"$ISSUE_KEY | $ISSUE_ASSIGNEE_NAME | $ISSUE_SUMMARY \", \"source\": { \"branch\": {\"name\": \"$branch\"}}, \"destination\": { \"branch\": {\"name\": \"release/$NEW_RELEASE_VERSION\"}}}"
        CREATE_PR_URL="$BB_BACKEND_URL/pullrequests"
        curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H 'Content-Type: application/json' -d "$CREATE_PR_PAYLOAD" "$CREATE_PR_URL"
    done <<< "$issue_info"
done

# ADMIN
for branch in "${ADMIN_BRANCH_NAMES[@]}"; do
    echo -e "PR from $branch to release/$NEW_RELEASE_VERSION. \n"
    while read -r ISSUE_ASSIGNEE_NAME && read -r ISSUE_KEY && read -r ISSUE_SUMMARY; do
        CREATE_PR_PAYLOAD="{\"title\": \"$ISSUE_KEY | $ISSUE_ASSIGNEE_NAME | $ISSUE_SUMMARY \", \"source\": { \"branch\": {\"name\": \"$branch\"}}, \"destination\": { \"branch\": {\"name\": \"release/$NEW_RELEASE_VERSION\"}}}"
        CREATE_PR_URL="$BB_ADMIN_URL/pullrequests"
        curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H 'Content-Type: application/json' -d "$CREATE_PR_PAYLOAD" "$CREATE_PR_URL"
    done <<< "$issue_info"

done

# FRONTEND
for branch in "${FRONTEND_BRANCH_NAMES[@]}"; do
    echo -e "PR from $branch to release/$NEW_RELEASE_VERSION. \n"

    while read -r ISSUE_ASSIGNEE_NAME && read -r ISSUE_KEY && read -r ISSUE_SUMMARY; do
        CREATE_PR_PAYLOAD="{\"title\": \"$ISSUE_KEY | $ISSUE_ASSIGNEE_NAME | $ISSUE_SUMMARY \", \"source\": { \"branch\": {\"name\": \"$branch\"}}, \"destination\": { \"branch\": {\"name\": \"release/$NEW_RELEASE_VERSION\"}}}"
        CREATE_PR_URL="$BB_FRONTEND_URL/pullrequests"
        curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H 'Content-Type: application/json' -d "$CREATE_PR_PAYLOAD" "$CREATE_PR_URL"
    done <<< "$issue_info"
done


# LICENSE BACKEND
for branch in "${LICENSE_BACKEND_BRANCH_NAMES[@]}"; do
    echo -e "PR from $branch to release/$NEW_RELEASE_VERSION. \n"

    while read -r ISSUE_ASSIGNEE_NAME && read -r ISSUE_KEY && read -r ISSUE_SUMMARY; do
        CREATE_PR_PAYLOAD="{\"title\": \"$ISSUE_KEY | $ISSUE_ASSIGNEE_NAME | $ISSUE_SUMMARY \", \"source\": { \"branch\": {\"name\": \"$branch\"}}, \"destination\": { \"branch\": {\"name\": \"release/$NEW_RELEASE_VERSION\"}}}"
        CREATE_PR_URL="$BB_LICENSE_BACKEND_URL/pullrequests"
        curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H 'Content-Type: application/json' -d "$CREATE_PR_PAYLOAD" "$CREATE_PR_URL"
    done <<< "$issue_info"
done

# LICENSE FRONTEND
for branch in "${LICENSE_FRONTEND_BRANCH_NAMES[@]}"; do
    echo -e "PR from $branch to release/$NEW_RELEASE_VERSION. \n"

    while read -r ISSUE_ASSIGNEE_NAME && read -r ISSUE_KEY && read -r ISSUE_SUMMARY; do
        CREATE_PR_PAYLOAD="{\"title\": \"$ISSUE_KEY | $ISSUE_ASSIGNEE_NAME | $ISSUE_SUMMARY \", \"source\": { \"branch\": {\"name\": \"$branch\"}}, \"destination\": { \"branch\": {\"name\": \"release/$NEW_RELEASE_VERSION\"}}}"
        CREATE_PR_URL="$BB_LICENSE_FRONTEND_URL/pullrequests"
        curl -s -X POST -H "Authorization:Basic $BB_API_TOKEN" -H 'Content-Type: application/json' -d "$CREATE_PR_PAYLOAD" "$CREATE_PR_URL"
    done <<< "$issue_info"
done

# Remove the fix versions from the tickets
# for ISSUE_KEY in $ISSUE_KEYS;do
#     echo "Removing Fix Version: $LATEST_VERSION from $ISSUE_KEY.\n"
#     FIX_VERSION_URL="$JIRA_BASE_URL/rest/api/2/issue/ISSUE_KEY"
#     FIX_VERSION_PAYLOAD="{\"update\": {\"fixVersions\": [{\"remove\": {\"name\": \"$LATEST_VERSION\"}}]}}"
#     curl -s -X PUT "$FIX_VERSION_URL" -H "Authorization: Basic $JIRA_API_TOKEN" -H "Content-Type: application/json" -d "$FIX_VERSION_PAYLOAD"  
# done

