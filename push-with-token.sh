#!/bin/bash
# Quick push script using token from environment or file
# Usage: 
#   GITHUB_TOKEN=your_token ./push-with-token.sh
#   OR
#   ./push-with-token.sh your_token

set -e

BRANCH="tg5040-performance-optimizations"
REMOTE="foxflyy"

# Get token from argument, environment, or file
if [ -n "$1" ]; then
    TOKEN="$1"
elif [ -n "$GITHUB_TOKEN" ]; then
    TOKEN="$GITHUB_TOKEN"
elif [ -f ".github_token" ]; then
    TOKEN=$(cat .github_token | tr -d '\n')
else
    echo "Error: No token provided"
    echo ""
    echo "Usage options:"
    echo "  1. GITHUB_TOKEN=token ./push-with-token.sh"
    echo "  2. ./push-with-token.sh your_token"
    echo "  3. Create .github_token file with your token"
    echo ""
    exit 1
fi

# Set remote with token
git remote set-url "$REMOTE" "https://${TOKEN}@github.com/foxflyy/NextUI.git"

# Push
echo "Pushing $BRANCH to foxflyy/NextUI..."
git push -u "$REMOTE" "$BRANCH"

echo "✓ Done!"

