Your task is to intelligently review, approve and manage dependabot PRs with comprehensive error handling and automated fixes.

## Prerequisites
- Use GitHub CLI (gh) for all GitHub operations
- Only work on repositories owned by the current GitHub CLI user
- You have full access to all Claude Code tools for code analysis and modifications

## Core Algorithm

### 1. Repository Validation
- Get current GitHub CLI user: `gh api user --jq '.login'`
- Filter PRs to only repositories owned by this user
- Skip any repositories not owned by the authenticated user

### 2. PR Discovery and Filtering
- Check current repo prs, or if current directory is not git repo check all folders in current directory
- Get all open PRs: `gh pr list --state open --json number,author,title,url,repository`
- Filter only dependabot PRs (author.login contains "dependabot")
- Process each dependabot PR individually

### 3. For Each Dependabot PR - Comprehensive Analysis

#### A. Conflict Detection and Resolution
- Check PR mergeable status: `gh pr view {PR_NUMBER} --json mergeable,mergeStateStatus`
- If mergeable is false or mergeStateStatus is "DIRTY":
  - Comment: `@dependabot rebase` to trigger automatic rebase
  - Wait 30 seconds, then poll every 60 seconds (max 10 minutes) for conflict resolution
  - If still conflicted after timeout, comment with manual intervention needed and skip

#### B. CI Status Monitoring with Intelligent Waiting
- Check CI status: `gh pr checks {PR_NUMBER} --json name,status,conclusion,detailsUrl`
- If checks are pending:
  - Wait and poll every 2 minutes (max 30 minutes)
  - Log progress of running checks
- If all checks pass: proceed to approval and merge
- If any checks fail: proceed to failure analysis

#### C. Test Failure Analysis and Auto-Fix
When CI checks fail:
1. **Analyze Failure Logs:**
   - Retrieve detailed failure logs from CI system
   - Use Claude Code tools to analyze test failures and build errors
   
2. **Code Analysis:**
   - Clone/checkout the PR branch locally if needed
   - Use Read, Grep, and other tools to analyze the codebase
   - Identify compatibility issues introduced by the dependency update
   
3. **Generate Fixes:**
   - Create necessary code changes to fix failing tests
   - Update configurations, imports, or API usage as needed
   - Ensure changes follow project's coding standards
   
4. **Create Fix PR:**
   - Create a new branch: `dependabot-fix-{original-pr-number}`
   - Apply the generated fixes
   - Create a new PR with:
     - Title: `Fix tests for dependabot PR #{original-pr-number}: {dependency-name}`
     - Body explaining the changes and linking to original PR
     - Base branch: the dependabot PR branch
   - Comment on original PR linking to the fix PR

### 4. Approval and Merge Process
If all checks pass and no conflicts exist:
- Review the dependency changes for security implications
- Approve the PR: `gh pr review {PR_NUMBER} --approve --body "Automated approval: all checks passed"`
- Merge the PR: `gh pr merge {PR_NUMBER} --squash --delete-branch`
- Log successful merge

### 5. Error Handling and Edge Cases

#### Network/API Failures
- Implement retry logic with exponential backoff
- Handle rate limiting gracefully
- Log all errors with context

#### Security Considerations
- For major version updates, require manual review
- Skip PRs that update security-critical dependencies without human approval
- Check for known vulnerabilities in the updated dependencies

#### Repository-Specific Rules
- Read `.dependabot.yml` or `.github/dependabot.yml` for custom rules
- Respect branch protection rules
- Handle different merge strategies per repository

#### Notification and Logging
- Log all actions taken with timestamps
- Send summary reports of processed PRs
- Alert on any PRs that require manual intervention

## Error Recovery
- If process fails at any step, log the error and continue with next PR
- Maintain state to avoid reprocessing successfully handled PRs
- Implement graceful shutdown on interruption

## Example Command Sequence
```bash
# 1. Verify user ownership
current_user=$(gh api user --jq '.login')

# 2. Get dependabot PRs for owned repos only  
gh pr list --state open --json number,author,title,url,repository | \
jq ".[] | select(.author.login | contains(\"dependabot\")) | select(.repository.owner.login == \"$current_user\")"

# 3. For each PR, execute the comprehensive workflow above
```

