#!/bin/bash
# Script to push code to GitHub fork
# Usage: ./push-to-github.sh [your_github_token]

set -e

BRANCH="tg5040-performance-optimizations"
REMOTE="foxflyy"
REPO_URL="https://github.com/foxflyy/NextUI.git"

echo "=========================================="
echo "Push to GitHub: foxflyy/NextUI"
echo "=========================================="
echo ""

# Check if we're on the right branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo "⚠ Current branch is: $CURRENT_BRANCH"
    echo "Expected branch: $BRANCH"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if remote exists
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
    echo "Adding remote: $REMOTE"
    git remote add "$REMOTE" "$REPO_URL"
fi

# Update remote URL to HTTPS
echo "Setting remote URL to HTTPS..."
git remote set-url "$REMOTE" "$REPO_URL"

# Check if token is provided as argument
if [ -n "$1" ]; then
    TOKEN="$1"
    echo "Using provided token..."
    # Set URL with token
    git remote set-url "$REMOTE" "https://${TOKEN}@github.com/foxflyy/NextUI.git"
else
    echo ""
    echo "GitHub requires a Personal Access Token (not password)"
    echo "Get one at: https://github.com/settings/tokens"
    echo ""
    echo "Required permissions: repo (all)"
    echo ""
    read -p "Enter your GitHub Personal Access Token: " -s TOKEN
    echo ""
    if [ -z "$TOKEN" ]; then
        echo "Error: Token is required"
        exit 1
    fi
    # Set URL with token
    git remote set-url "$REMOTE" "https://${TOKEN}@github.com/foxflyy/NextUI.git"
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo ""
    echo "⚠ You have uncommitted changes!"
    git status --short
    echo ""
    read -p "Commit changes before pushing? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add -A
        git commit -m "Update: $(date +%Y-%m-%d)"
    else
        echo "Aborting. Please commit or stash changes first."
        exit 1
    fi
fi

# Show what will be pushed
echo ""
echo "Ready to push:"
echo "  Branch: $BRANCH"
echo "  Remote: $REMOTE -> $REPO_URL"
echo ""
git log --oneline origin/main..HEAD 2>/dev/null || git log --oneline -5
echo ""

read -p "Push to GitHub? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Push
echo ""
echo "Pushing to GitHub..."
if git push -u "$REMOTE" "$BRANCH"; then
    echo ""
    echo "✓ Successfully pushed to GitHub!"
    echo ""
    echo "View your branch at:"
    echo "  https://github.com/foxflyy/NextUI/tree/$BRANCH"
    echo ""
    echo "To create a Pull Request, visit:"
    echo "  https://github.com/foxflyy/NextUI/compare/main...$BRANCH"
else
    echo ""
    echo "✗ Push failed. Check the error above."
    exit 1
fi

