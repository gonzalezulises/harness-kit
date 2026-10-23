# Account profile for bin/harness-wiring.sh — identifiers only, NEVER secrets.
# Copy to ~/.config/harness-kit/profiles/<github-owner>.profile (one file per GitHub owner).
# Tokens stay where they already live: `gh auth token --user`, the Vercel CLI session,
# gcloud, and the OS keychain.

# The email commits to this owner's repos must carry (checked against `git config user.email`).
GIT_EMAIL="you@example.com"

# The gh account whose token can administer this owner's repos (`gh auth token --user <name>`).
GH_USER="your-github-login"

# Vercel team id of the projects these repos deploy to (informational; the project id comes from .vercel/).
VERCEL_TEAM=""

# GCP project where this owner's Cloud Build triggers and Cloud Run services live.
GCP_PROJECT=""

# Keychain items to try, in order, for the Supabase Management API. Each can see different orgs.
SUPABASE_KEYCHAIN_ITEMS="SUPABASE_ACCESS_TOKEN,Supabase CLI"
