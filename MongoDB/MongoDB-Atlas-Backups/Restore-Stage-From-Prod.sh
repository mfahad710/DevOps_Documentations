# Generate a Shell script that will use the Atlas API to restore Stage cluster from a Production Cluster snapshot.
# Both Cluster are in different Atlas Projects (Groups).
# The script should do the following:

# 1. Use the Atlas API to get a list of snapshots for a given cluster.
# 2. Get the snapshot ID for the most recent snapshot.
# 3. Use the Atlas API to restore a cluster from the parsed snapshot ID.
# 4. The script should take the following arguments:
#    - Atlas API key
#    - Atlas group ID
#    - Atlas cluster name
#    - Atlas target group ID
#    - Atlas target cluster name
# These arguments will be passed as environment variables.
# 5. The script should output the restore job ID.
# 6. The script should also clear all collections in the target (Stage) cluster before restoring the (Production) snapshot.

#!/bin/bash

# Environmental Variables file
source auth_variables.sh

# Clear collections
echo "Clearing Stage Databases collections..."

# Drop all collections in each database
# The connection strings are passed as environment variables
# The connection strings are used to connect to the MongoDB cluster
# The mongosh command is used to drop all collections in each database
# The --eval flag is used to evaluate the JavaScript code that drops all collections in each database
# The --quiet flag is used to suppress the output of the command
# The JavaScript code uses the db.getCollectionNames() method to get a list of collections in each database
# The forEach() method is used to iterate over the list of collections and drop each collection
# The db[collection].drop() method is used to drop each collection

# we have 2 databases in the cluster. we will drop all the collections in each database
mongosh "$CONNECTION_STRING_FORT"  --eval "db.getCollectionNames().forEach(function(collection) { db[collection].drop() })" --quiet
mongosh "$CONNECTION_STRING_FORT_ADMIN"  --eval "db.getCollectionNames().forEach(function(collection) { db[collection].drop() })" --quiet

echo "Cleared Stage Databases collections"

echo "Restoring Stage cluster from Production Cluster snapshot..."

# Send a GET request to retrieve the list of snapshots in the production cluster
# The response is stored in a variable
response=$(curl --user "$ATLAS_API_PUBLIC_KEY:$ATLAS_API_PRIVATE_KEY" --digest \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --request GET "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_GROUP_ID/clusters/$ATLAS_CLUSTER_NAME/backup/snapshots?pretty=true")


# If the request fails, then echo a message
if [ "$response" = "" ]; then
    echo "Failed to get snapshots"
    exit 1
fi
# Parse the response to get the latest snapshot ID
snapshot_id=$(echo "$response" | jq -r '.results[0].id')

echo "Snapshot ID: $snapshot_id"

# Send a POST request to restore the cluster using the parsed snapshot ID
restore_response=$(curl --user "$ATLAS_API_PUBLIC_KEY:$ATLAS_API_PRIVATE_KEY" --digest \
                        --header "Accept: application/json" \
                        --header "Content-Type: application/json" \
                        --request POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/$ATLAS_GROUP_ID/clusters/$ATLAS_CLUSTER_NAME/backup/restoreJobs?pretty=true" \
                        --data '
                        {
                            "deliveryType" : "automated",
                            "targetGroupId" : "'$ATLAS_TARGET_GROUP_ID'",
                            "targetClusterName" : "'$ATLAS_TARGET_CLUSTER_NAME'",
                            "snapshotId": "'$snapshot_id'"
                        }'
)


# if the request failes then echo message
if [ "$restore_response" = "" ]; then
    echo "Failed to restore cluster"
    exit 1
fi

# Extract the restore job ID from the response
restore_job_id=$(echo "$restore_response" | jq -r '.id')

# Output the restore job ID
echo "Restore Job ID: $restore_job_id"

if [ "$restore_job_id" = "null" ]; then
    echo "Failed to get restore job ID from response, Restore might have failed."
    echo "Response: $restore_response"
    exit 1
fi

echo "Restoring cluster from snapshot...:"
