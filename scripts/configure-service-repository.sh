#!/usr/bin/env bash
set -euo pipefail

repository="${1:?usage: configure-service-repository.sh OWNER/REPOSITORY}"

gh api --method PATCH "repos/${repository}" -f allow_auto_merge=true >/dev/null
gh api --method PUT "repos/${repository}/branches/main/protection" --input - <<'JSON' >/dev/null
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["observability-manifest / validate-observability-manifest"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON

echo "Configured ${repository}: manifest check + one approval + CODEOWNERS + auto-merge."

