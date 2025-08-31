# Enabling CORS in GCP Storage Bucket

## Overview

Cross-Origin Resource Sharing (CORS) is a mechanism that allows web
applications running on one origin to access resources from a different
origin. This guide outlines how to enable CORS on a GCS bucket to
support cross-origin requests.

## Prerequisites

-   Google Cloud SDK installed on your local machine\
    [Install the gcloud CLI \| Google Cloud SDK
    Documentation](https://cloud.google.com/sdk/docs/install)
-   Access permissions to update bucket settings (**Storage Admin** role
    recommended)

## Step 1: Create a CORS Configuration File

Create a file named `cors.json` with the desired CORS policy.

### Sample Configuration

``` json
[
  {
    "origin": ["http://localhost:3000", "https://test.fortrans.com"],
    "method": ["GET"],
    "responseHeader": ["Content-Length"],
    "maxAgeSeconds": 3600
  }
]
```

> Change `origin` as per requirements.

## Step 2: Check CORS Configuration

To check the configuration:

``` bash
gsutil cors get gs://YOUR_BUCKET_NAME
```

### Example:

``` bash
gsutil cors get gs://fort-test-bucket
```

## Step 3: Apply CORS Configuration to GCS Bucket

Use the following `gsutil` command to apply the configuration:

``` bash
gsutil cors set cors.json gs://YOUR_BUCKET_NAME
```

### Example:

``` bash
gsutil cors set cors.json gs://fort-test-bucket
```

## Step 4: Verify CORS Configuration

To confirm that the configuration was applied successfully:

``` bash
gsutil cors get gs://YOUR_BUCKET_NAME
```

The output should match the contents of your `cors.json` file.

## Remove CORS Configuration

To remove all CORS settings from the bucket:

``` bash
gsutil cors set /dev/null gs://YOUR_BUCKET_NAME
```

## Additional Notes

-   CORS settings can take a few minutes to propagate.
-   You can define multiple CORS rules in the same JSON file.
-   GCS buckets do not support wildcard subdomains (e.g.,
    `"*.example.com"`); list each origin explicitly.
