# AzCopy
AzCopy is a command-line utility designed for high-performance data transfer between local file systems and Azure Blob Storage, Azure Files, and Azure Data Lake Storage. It provides efficient and reliable data migration with features like resume capability, parallel transfers, and bandwidth throttling.

## Installation

[Installation Link](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10?tabs=dnf#download-the-azcopy-portable-binary)

## Basic Syntax

```bash
azcopy <command> <source> <destination> [flags]
```

## Example Scenario
I want to transfer data from one storage account to another storage account through bash Script

**Craete transfer script as** 
```bash
touch data-transfer.sh
```

**make it executable**
```bash
chmod +x data-transfer.sh
```

Open file in editor
```bash
vi data-transfer.sh
```

**Script**

```bash
#!/bin/bash

# Variables

## Primary Storage Account details
## Replace the placeholders with actual values
SOURCE_ACCOUNT_NAME="primaryStorageAccount"

SOURCE_PRIVATE_CONTAINER_NAME="primary-private-container"
SOURCE_PRIVATE_SAS_TOKEN="<SAS_TOKEN_FOR_PRIVATE_CONTAINER>"

SOURCE_PUBLIC_CONTAINER_NAME="primary-public-container"
SOURCE_PUBLIC_SAS_TOKEN="<SAS_TOKEN_FOR_PUBLIC_CONTAINER>"

## Secondary Storage Account details
## Replace the placeholders with actual values
DES_ACCOUNT_NAME="secondaryStorageAccount"

DES_PRIVATE_CONTAINER_NAME="secondary-private-container"
DES_PRIVATE_SAS_TOKEN="<SAS_TOKEN_FOR_PRIVATE_CONTAINER>"

DES_PUBLIC_CONTAINER_NAME="secondary-public-container"
DES_PUBLIC_SAS_TOKEN="<SAS_TOKEN_FOR_PUBLIC_CONTAINER>"

## AzCopy command to copy data from one storage account to another

# First we remove any existing data in the seconddary account containers
# Private container
azcopy rm "https://$DES_ACCOUNT_NAME.blob.core.windows.net/$DES_PRIVATE_CONTAINER_NAME?$DES_PRIVATE_SAS_TOKEN" --recursive

# Public container
azcopy rm "https://$DES_ACCOUNT_NAME.blob.core.windows.net/$DES_PUBLIC_CONTAINER_NAME?$DES_PUBLIC_SAS_TOKEN" --recursive

# Transfer data from primary to secondary account
# Private container
azcopy copy "https://$SOURCE_ACCOUNT_NAME.blob.core.windows.net/$SOURCE_PRIVATE_CONTAINER_NAME?$SOURCE_PRIVATE_SAS_TOKEN" "https://$DES_ACCOUNT_NAME.blob.core.windows.net/$DES_PRIVATE_CONTAINER_NAME?$DES_PRIVATE_SAS_TOKEN" --recursive

# Public container
azcopy copy "https://$SOURCE_ACCOUNT_NAME.blob.core.windows.net/$SOURCE_PUBLIC_CONTAINER_NAME?$SOURCE_PUBLIC_SAS_TOKEN" "https://$DES_ACCOUNT_NAME.blob.core.windows.net/$DES_PUBLIC_CONTAINER_NAME?$DES_PUBLIC_SAS_TOKEN" --recursive

echo "Data copy completed successfully!"
```