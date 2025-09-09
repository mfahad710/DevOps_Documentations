# auth_variables.sh
export ATLAS_API_PUBLIC_KEY=<PUBLIC_KEY>
export ATLAS_API_PRIVATE_KEY=<PRIVATE_KEY>

# Production Cluster details
export ATLAS_GROUP_ID=<PRODUCTION_GROUP_ID>
export ATLAS_CLUSTER_NAME=<PRODUCTION_CLUSTER_NAME>

# Stage Cluster details
export ATLAS_TARGET_GROUP_ID=<STAGE_GROUP_ID>
export ATLAS_TARGET_CLUSTER_NAME=<STAGE_CLUSTER_NAME>

# Stage Databases are in the MongoDB Atlas
export CONNECTION_STRING_FORT="mongodb+srv://<FORT_USERNAME>:<PASSWORD>@fort-db.ylba6.mongodb.net/fort"
export CONNECTION_STRING_FORT_ADMIN="mongodb+srv://<FORT_ADMIN_USERNAME>:<PASSWORD>@fort-db.ylba6.mongodb.net/fort-admin"