# Push Docker Images to GCP Artifact Registry

## Overview
This guide outlines the steps to build, tag, and push Docker images to Google Cloud Artifact Registry in the `asia-southeast1` region.

## Prerequisites
- Google Cloud SDK (`gcloud`) installed  
    [Google Cloud SDK Documentation](https://cloud.google.com/sdk/docs/install)
- Docker installed

## Step 1: Enable Artifact Registry API
Enable the Artifact Registry API via the [GCP Console](https://console.cloud.google.com/).

## Step 2: Authenticate & Configure gcloud
1. Authenticate with Google Cloud:
```bash
gcloud auth login
```
2. Set the target project:
```bash
gcloud config set project [PROJECT_ID]
```
Replace `[PROJECT_ID]` with your actual Google Cloud Project ID.

## Step 3: Configure Docker to Authenticate with Artifact Registry
```bash
gcloud auth configure-docker asia-southeast1-docker.pkg.dev
```
This sets up Docker to authenticate with Artifact Registry when pushing images.

## Step 4: Tag Docker Image
Tag your local Docker image using the Artifact Registry hostname:
```bash
docker tag [LOCAL_IMAGE_NAME] asia-southeast1-docker.pkg.dev/[PROJECT_ID]/[REPO_NAME]/[IMAGE_NAME]:[TAG]
```
**Example:**
```bash
docker tag fort_stage:latest asia-southeast1-docker.pkg.dev/fort-47708/fort/fort_stage:latest
```

## Step 5: Push the Docker Image to Artifact Registry
```bash
docker push asia-southeast1-docker.pkg.dev/[PROJECT_ID]/[REPO_NAME]/[IMAGE_NAME]:[TAG]
```
**Example:**
```bash
docker push asia-southeast1-docker.pkg.dev/fort-47708/fort/fort_stage:latest
```
