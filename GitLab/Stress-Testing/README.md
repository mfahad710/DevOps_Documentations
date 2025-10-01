# Stress Testing

This repository contains comprehensive testing suites for Stress Testing.

## Overview

The Stress Testing project provides automated testing infrastructure to ensure the reliability, performance, and functionality. The testing suite is designed to validate transaction APIs, authentication flows, and system performance under various load conditions.

## Purpose

- **Performance Validation**: Ensure system can handle expected transaction loads
- **API Reliability**: Validate transaction flow integrity under stress conditions
- **Quality Assurance**: Maintain high standards for payment system functionality
- **Regression Prevention**: Detect issues before production deployment

## Testing Strategies

### Stress Testing
**Purpose**: Validate system performance under sustained load conditions

**Implementation**:
- **Tool**: Apache JMeter 5.6.3
- **Duration**: 8-hour continuous testing window
- **Load Pattern**: 6 concurrent threads with constant throughput
- **Target Throughput**: 8.5 transactions per minute
- **Test Data**: Round-robin card selection from 1001+ test cards

## Getting Started

### Prerequisites
- Apache JMeter 5.5 or higher
- GitLab Runner with Docker support (for CI/CD)

## CI/CD Configuration

**Install JMeter on Gitlab Runner server**
```bash
# Download and install JMeter from https://jmeter.apache.org/
# Or use Docker:
docker pull justb4/jmeter:5.5
```

### GitLab CI Pipeline
**File**: `.gitlab-ci.yml`

**Pipeline Configuration**:
- **Workflow**: Triggered on stress-testing branch commits
- **Image**: `justb4/jmeter:5.5` (Docker-based JMeter execution)
- **Runner Tags**: `Stress_Test_Docker_Runner`
- **Execution**: Manual trigger with 9-hour timeout

**Pipeline Stages**:
1. **stress-test**: Single stage focused on JMeter execution

**Artifacts Generated**:
- `results-report.jtl`: Raw test results in JTL format
- `stress-test.log`: JMeter execution logs
- `html-report/`: Complete HTML dashboard with performance metrics

**Key Features**:
- **Long-running Support**: 9-hour timeout for extended stress testing
- **Failure Tolerance**: `allow_failure: true` prevents pipeline blocking
- **Comprehensive Artifacts**: Full result retention for analysis

## Execution Methods

### Local Execution

**Command Line (Non-GUI)**:
```bash
# Execute test
jmeter -n -t JMX_Files/TransactionAPIsStressTesting.jmx -l JMX_Files/results-report.jtl -j JMX_Files/stress-test.log

# Generate HTML report
jmeter -g JMX_Files/results-report.jtl -o JMX_Files/html-report
```

**Docker Execution**:
```bash
docker run --rm -v $(pwd):/mnt -w /mnt justb4/jmeter:5.5 -n -t JMX_Files/TransactionAPIsStressTesting.jmx -l JMX_Files/results-report.jtl -j JMX_Files/stress-test.log
```

### GitLab CI Execution
1. Push changes to stess-testing branch
2. Pipeline code present in the `.gitlab-ci.yml` file
3. Navigate to GitLab CI/CD → Pipelines
4. Manually trigger the `jmeter_stress_test` job
5. Monitor execution through GitLab interface
6. Download artifacts after completion

## Key Metrics Tracked
- Transaction success/failure rates
- Response times for each API endpoint
- System throughput under load
- Error patterns and failure analysis
