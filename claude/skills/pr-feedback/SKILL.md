---
name: pr-feedback
description: Address PR review comments one by one with user confirmation
argument-hint: [pr-number]
disable-model-invocation: true
---

BEFORE ANYTHING ELSE, YOU NEED A PR NUMBER TO CONTINUE. YOU CAN:

- check current branch against current active PRs
- ask the user to confirm

IF YOU ARE UNSURE ABOUT THE PR NUMBER, ASK USER FOR CONFIRMATION!

Address PR review comments one by one with user confirmation.

## Procedure

1. **Verify correct branch**

   After getting the PR number, verify the current branch matches the PR's head branch:

   ```bash
   # Get PRs head branch
   PR_BRANCH=$(gh pr view <pr-number> --json headRefName --jq '.headRefName')
   CURRENT_BRANCH=$(git branch --show-current)

   if [ "$CURRENT_BRANCH" != "$PR_BRANCH" ]; then
     echo "WARNING: Current branch ($CURRENT_BRANCH) does not match PR branch ($PR_BRANCH)"
   fi
   ```

   - If branches don't match, **STOP** and ask user:
     - "You're on `<current-branch>` but PR #X is on `<pr-branch>`. Switch to correct branch? (YES / NO)"
     - If YES: `git checkout <pr-branch>`
     - If NO: Abort and explain they need to be on the correct branch

2. **Fetch PR review comments**

   ```bash
   gh api repos/:owner/:repo/pulls/<pr-number>/comments --paginate | jq -r '.[] | "---\n## Comment \(.id)\n**File:** \(.path):\(.line)\n**Suggestion:**\n\(.body)\n"'
   ```

3. **Present summary table**

   - Show all comments in a numbered table with:
     - File and line number
     - Brief description of the issue
     - Priority (High/Medium/Low based on severity)
   - Group related comments (e.g., all deprecation warnings together)

4. **Analyze all the comments**

   - Analyze each of the comments
   - Determine if they are valid or false positive
   - Determine the severity level
   - Present a summary, and inform user of auto-skipped comments

5. **Process valid comments one by one**

   - For each valid comment, show:
     - The file and line number
     - The full issue description
     - The suggested fix (if provided)
   - Ask user for confirmation:
     - **YES** - Fix this comment
     - **SKIP** - Move to next comment
     - **YES ALL [GROUP]** - Fix all related comments together (e.g., "YES ALL CHRONO" for deprecation fixes)
   - If fixing:
     - Read the relevant file section
     - Apply the fix
     - Do NOT verify yet (defer to end)
     - Mark as fixed and move to next

6. **Skip verification during fixes**

   - Do NOT run `cargo check`, `clippy`, or `lsp_diagnostics` after each fix
   - This speeds up the feedback loop
   - All verification happens at the end

7. **Final verification (after all comments processed)**

   ```bash
   cargo fmt --all --check
   cargo clippy --all-targets --all-features -- -D warnings
   cargo build
   cargo test
   ```

   - If any check fails, report and offer to fix

8. **Commit and push**

   - Show summary of changes:
     - Number of comments fixed
     - Number of comments skipped
     - Files modified
   - Ask user for commit message or suggest:

     ```
     fix: address PR #<number> review feedback

     - <brief list of changes>
     ```

   - Commit and push:
     ```bash
     git add -A
     git commit -m "<message>"
     git push
     ```

9. **Resolve comments and post summary**

   After pushing, resolve all addressed review comments and post a summary:

   - **Resolve review threads** (for each fixed comment):

     ```bash
     # Get the GraphQL node_id for the review thread
     gh api graphql -f query='
       query($owner: String!, $repo: String!, $pr: Int!) {
         repository(owner: $owner, name: $repo) {
           pullRequest(number: $pr) {
             reviewThreads(first: 100) {
               nodes {
                 id
                 isResolved
                 comments(first: 1) {
                   nodes {
                     databaseId
                     path
                     body
                   }
                 }
               }
             }
           }
         }
       }
     ' -f owner=':owner' -f repo=':repo' -F pr=<pr-number>
     ```

   - **Resolve each thread** (for fixed comments):

     ```bash
     gh api graphql -f query='
       mutation($threadId: ID!) {
         resolveReviewThread(input: {threadId: $threadId}) {
           thread { isResolved }
         }
       }
     ' -f threadId='<thread-node-id>'
     ```

   - **If resolving fails** (e.g., not a review thread), delete the comment:

     ```bash
     gh api -X DELETE repos/:owner/:repo/pulls/comments/<comment-id>
     ```

   - **Post summary comment** on the PR:

     ```bash
     gh pr comment <pr-number> --body "$(cat <<'EOF'
     ## PR Feedback Addressed

     The following review comments have been addressed in the latest push:

     | File | Issue | Status |
     |------|-------|--------|
     | `<path>:<line>` | <brief description> | Fixed |
     | `<path>:<line>` | <brief description> | Skipped |

     EOF
     )"
     ```

## Comment Classification

When presenting comments, classify by priority:

| Priority | Criteria                                                      |
| -------- | ------------------------------------------------------------- |
| High     | Bugs, security issues, key conflicts, breaking changes        |
| Medium   | Deprecation warnings, missing error handling, code quality    |
| Low      | Style suggestions, minor optimizations, optional improvements |

## Grouping Related Comments

Identify and group related comments to offer batch fixes:

| Group   | Trigger                              | Example           |
| ------- | ------------------------------------ | ----------------- |
| CHRONO  | Multiple `and_hms_opt` deprecations  | "YES ALL CHRONO"  |
| TIMEOUT | Multiple timeout-related issues      | "YES ALL TIMEOUT" |
| ERROR   | Multiple error handling improvements | "YES ALL ERROR"   |

## Handling False Positives

If a comment appears incorrect or already resolved:

1. Check the actual code to verify
2. If already correct, note: "**SKIP this comment?** (YES to skip / NO to investigate)"
3. Mark as SKIPPED with reason: "Code already correct" or "False positive"

## Notes

- Always fetch the latest PR comments before starting
- Defer ALL verification to the end for speed
- Offer grouped fixes for related issues to reduce confirmation fatigue
- If verification fails, do NOT auto-commit - report and offer fixes first
- The final push updates the PR automatically
- After pushing, always resolve addressed comments and post a summary
- If a comment cannot be resolved (not a review thread), delete it instead
- The summary comment provides a clear audit trail of what was addressed

## Current Context

Repository:
!`gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"' 2>/dev/null || echo "not a gh repo"`

Open PRs:
!`gh pr list --state open --json number,title,reviewDecision --jq '.[] | "- #\(.number) \(.title) [\(.reviewDecision // "pending")]"' 2>/dev/null || echo "no open PRs"`

Current branch:
!`git branch --show-current`

Git status:
!`git status --porcelain`
