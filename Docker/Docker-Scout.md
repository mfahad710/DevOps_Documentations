# Docker Scout

## Introduction

Docker Scout is a vulnerability scanning and security analysis tool for container images. It helps identify **OS-level vulnerabilities**, **Application dependency vulnerabilities** (npm, pip, etc.), **Base image risks**, **Recommended updates**.

### Installation (Linux)

Installation Guide Link: [Docker_Scout](https://docs.docker.com/scout/install/)

## Basic Commands

### Quick Overview Scan

``` bash
docker scout quickview <image-name>
```

Example:

``` bash
docker scout quickview pms-frontend:latest
```

### Detailed Vulnerability Report

``` bash
docker scout cves <image-name>
```

### Base Image Recommendations

``` bash
docker scout recommendations <image-name>
```

### Generate SBOM

``` bash
docker scout sbom <image-name>
```

## Understanding Output

Vulnerability severity levels:

-   CRITICAL
-   HIGH
-   MEDIUM
-   LOW


## CI/CD Integration (GitLab Example)

``` yaml
docker_scout_scan:
  stage: security
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker scout cves myimage:latest --exit-code
```

`--exit-code` will fail the pipeline if **HIGH** or **CRITICAL** vulnerabilities are found.
