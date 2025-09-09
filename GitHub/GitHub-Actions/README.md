# GitHub Actions
It's a platform built directly into GitHub that allows you to automate software development workflows.

We give it a set of instructions (**"workflow"**), and it will automatically execute those instructions based on events that happen in our repo, like a push to main, a pull request, or on a schedule.

## Key Capabilities:

- `CI/CD` (Continuous Integration/Continuous Deployment): Automatically build, test, and deploy your code.
- `Scheduled Tasks`: Run scripts on a cron schedule (e.g., nightly database backups, weekly dependency updates).

## Core Components

- `Workflow`: The main unit of automation. It's an automated procedure that we add to our repository. A repository can have multiple workflows, each performing a different set of tasks. Workflows are defined by a YAML (`.yml` or `.yaml`) file.
- `Event`: The specific activity that triggers a workflow run. Examples: push, pull_request, issue_opened, schedule.
- `Job`: A set of steps that execute on the same runner. A workflow can contain multiple jobs, which can run in parallel or sequentially.
- `Step`: An individual task that can run a command (npm install) or an action. Steps are executed in order.
- `Action`: A standalone, reusable command. They are the smallest portable building block of a workflow.
- `Runner`: A server with the GitHub Actions runner application installed. It waits for a job, runs it, and reports back the progress and results. GitHub provides hosted runners (Ubuntu, Windows, macOS), or we can host our own.

## `.github/workflows/` Directory
The `.github/workflows` directory is the designated location where GitHub looks for workflow files.

**Location and Structure**  

- **Path**: It must be in the root of our GitHub repository.
- **Naming**: The directory name is fixed. It must be exactly `.github/workflows/`
- **Files**: We place our YAML workflow files inside this directory. We can have multiple files (e.g., `ci.yml`, `deploy.yml`). GitHub will automatically detect and run all of them based on their triggers.