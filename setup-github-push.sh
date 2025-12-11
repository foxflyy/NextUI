#!/bin/bash
# Setup script for GitHub push configuration

echo "=========================================="
echo "GitHub Push Setup"
echo "=========================================="
echo ""

# Check current status
echo "Current branch: $(git branch --show-current)"
echo "Current remotes:"
git remote -v
echo ""

# Add/update foxflyy remote
if git remote get-url foxflyy >/dev/null 2>&1; then
    echo "Remote 'foxflyy' already exists"
    read -p "Update it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote set-url foxflyy https://github.com/foxflyy/NextUI.git
        echo "✓ Updated remote"
    fi
else
    git remote add foxflyy https://github.com/foxflyy/NextUI.git
    echo "✓ Added remote 'foxflyy'"
fi

echo ""
echo "=========================================="
echo "Authentication Options"
echo "=========================================="
echo ""
echo "GitHub no longer accepts passwords. Choose an option:"
echo ""
echo "Option 1: Personal Access Token (Easiest)"
echo "  1. Go to: https://github.com/settings/tokens"
echo "  2. Generate new token (classic)"
echo "  3. Select 'repo' scope"
echo "  4. Copy the token"
echo "  5. Use: GITHUB_TOKEN=your_token ./push-with-token.sh"
echo ""
echo "Option 2: SSH Keys (More secure, one-time setup)"
echo "  1. Generate SSH key: ssh-keygen -t ed25519 -C 'your_email@example.com'"
echo "  2. Add to GitHub: https://github.com/settings/keys"
echo "  3. Use: git remote set-url foxflyy git@github.com:foxflyy/NextUI.git"
echo ""
echo "Option 3: GitHub CLI (gh)"
echo "  1. Install: sudo apt install gh"
echo "  2. Login: gh auth login"
echo "  3. Push normally: git push foxflyy tg5040-performance-optimizations"
echo ""

# Check if gh CLI is installed
if command -v gh &> /dev/null; then
    echo "✓ GitHub CLI (gh) is installed!"
    if gh auth status &>/dev/null; then
        echo "✓ Already authenticated with GitHub CLI"
        echo ""
        echo "You can push directly with:"
        echo "  git push foxflyy tg5040-performance-optimizations"
    else
        echo "Run 'gh auth login' to authenticate"
    fi
fi

echo ""
echo "Ready to push! Use one of these commands:"
echo "  ./push-to-github.sh"
echo "  ./push-with-token.sh YOUR_TOKEN"
echo "  GITHUB_TOKEN=YOUR_TOKEN ./push-with-token.sh"

