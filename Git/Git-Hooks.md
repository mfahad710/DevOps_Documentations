# Git Hook

Git hooks are automated scripts that run before or after specific Git events (like commits, pushes, merges, etc.). They're built-in feature that lets we customize and automate our Git workflow.

### Characteristics
- Located in `.git/hooks/` directory of any Git repository
- Local by default (**not tracked by Git**)
- Triggered automatically by Git events.

## Common Hook Types

### Client-side Hooks (run on our machine)

Pre-commit (`pre-commit`)

- Runs **before** you make a commit
- **Use for:** code linting, formatting checks, running tests
- **Example:** Prevent commit if tests fail

Prepare-commit-msg (`prepare-commit-msg`)

- Edit commit message before it's finalized
- **Use for:** adding templates, standardizing messages

Pre-push (`pre-push`)

- Runs before pushing to remote
- **Use for:** running full test suite, checking branch naming

Post-commit (`post-commit`)

- Runs after a commit is made
- **Use for:** notifications, logging

### Server-side Hooks (run on Git server like GitHub, GitLab)

Pre-receive (`pre-receive`)

- Runs when server receives a push
- **Use for:** enforcing policies, access control

Update (`update`)

- Similar to pre-receive but runs per branch

Post-receive (`post-receive`)

- Runs after server accepts push
- **Use for:** CI/CD triggers, deployment notifications


### Common Use Cases
- Run **linters/formatters** before commit
- Prevent committing to **wrong branches**
- Add **ticket numbers to commit messages**
- Run **tests before pushing**
- Validate **code style/patterns**
- Auto-update dependencies
- **Send notifications** after deployment

## Share Hooks with Team
The Git hook is NOT pushed with our changes to the repository. (Local Hooks Stay Local)  
Since `.git/hooks/` isn't tracked:  Store hooks in project (e.g., `git-hooks/` directory)

Create `git-hooks` directory and `githooks-setup.sh` file in the **project root** which is use for automatically setting up the hooks in other team member local machine.


`githooks-setup.sh`
```bash
#!/bin/bash
cp ./git-hooks/* .git/hooks/

# change the permission of the hooks
chmod +x .git/hooks/<hook-file>
```