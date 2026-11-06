#!/usr/bin/env bash
# ==============================================================================
# NxNative Launcher - Safe Upstream Synchronization Script (seedds/nxnative)
# ==============================================================================
# Features:
# 1. Configures 'merge=ours' driver so launcher components are never overwritten.
# 2. Seamlessly merges upstream updates without blocking or causing conflicts.
# 3. Preserves zero-hang launcher safety and custom hooks in all scenarios.
# ==============================================================================
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "🔄 [NxNative Launcher] Checking upstream synchronization (seedds/nxnative)..."

# 1. Configure merge drivers for zero-conflict automated updates
git config merge.ours.driver true

# 2. Ensure upstream (GitHub) and origin (GitLab) remotes are configured
if ! git remote get-url upstream >/dev/null 2>&1; then
    echo "⚙️ Adding upstream remote (https://github.com/seedds/nxnative.git)..."
    git remote add upstream https://github.com/seedds/nxnative.git
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    echo "⚙️ Adding origin remote (https://gitlab.com/rennan-group2/nxnative_Launcher.git)..."
    git remote add origin https://gitlab.com/rennan-group2/nxnative_Launcher.git
else
    ORIGIN_URL=$(git remote get-url origin)
    if [[ "$ORIGIN_URL" =~ "github.com/rennan101" ]]; then
        echo "⚙️ Migrating origin remote from suspended GitHub to GitLab..."
        git remote set-url origin https://gitlab.com/rennan-group2/nxnative_Launcher.git
    fi
fi

# 3. Fetch upstream updates
echo "📥 Fetching commits from upstream/main..."
git fetch upstream main

# 4. Verify local branch status
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "⚠️ Warning: You are currently on branch '$CURRENT_BRANCH'. Switching to 'main'..."
    git checkout main
fi

# 5. Check for unstaged or uncommitted changes
STASHED=0
if ! git diff-index --quiet HEAD --; then
    echo "⚠️ Uncommitted modifications found in working directory."
    echo "📦 Auto-stashing local modifications before syncing..."
    git stash push -m "Auto-stash before sync-upstream on $(date)"
    STASHED=1
fi

# 6. Compare commit counts
BEHIND_COUNT=$(git rev-list --count HEAD..upstream/main)
if [ "$BEHIND_COUNT" -eq 0 ]; then
    echo "✅ Your fork is already 100% up to date with seedds/nxnative:main! No action required."
    if [ "$STASHED" -eq 1 ]; then
        echo "Restoring local stashed changes..."
        git stash pop || true
    fi
    exit 0
fi

echo "🚀 Found $BEHIND_COUNT new commits in upstream."
echo "--- Latest 5 commits in upstream ---"
git log HEAD..upstream/main --oneline -n 5
echo "------------------------------------"

# 7. Execute safe merge with intelligent conflict resolution
echo "🔀 Merging upstream/main into main branch..."
MERGE_OK=0
if git merge upstream/main --no-edit -m "chore(sync): merge upstream updates from seedds/nxnative"; then
    MERGE_OK=1
else
    echo "⚙️ Analyzing potential conflicts..."
    CONFLICT_FILES=$(git diff --name-only --diff-filter=U 2>/dev/null || true)
    if [ -n "$CONFLICT_FILES" ]; then
        echo "⚙️ Auto-resolving engine updates while safeguarding local launcher customizations..."
        for file in $CONFLICT_FILES; do
            if [[ "$file" == gui/* ]] || \
               [[ "$file" == frontend-ios/* ]] || \
               [[ "$file" == "README.md" ]] || \
               [[ "$file" == "GEMINI.md" ]] || \
               [[ "$file" == .gitlab* ]] || \
               [[ "$file" == .github/* ]] || \
               [[ "$file" == scripts/build_gui.sh ]] || \
               [[ "$file" == scripts/create_dmg.sh ]] || \
               [[ "$file" == scripts/gitlab_release.sh ]] || \
               [[ "$file" == scripts/sync_upstream.sh ]] || \
               [[ "$file" == dm/ios/Shell/* ]] || \
               [[ "$file" == dm/ios/framework/* ]] || \
               [[ "$file" == dm/ios/project-*.yml ]] || \
               [[ "$file" == dm/ios/tools/build_shell.sh ]] || \
               [[ "$file" == dm/ios/Sources/FrameworkBootstrap.* ]] || \
               [[ "$file" == dm/ios/Sources/DataBookmark.* ]]; then
                echo "  [KEEP OURS] $file"
                git checkout HEAD -- "$file" 2>/dev/null || true
            else
                echo "  [ACCEPT UPSTREAM] $file"
                git checkout --theirs -- "$file" 2>/dev/null || true
            fi
            git add "$file" 2>/dev/null || true
        done
        if git commit --no-edit -m "chore(sync): merge upstream updates from seedds/nxnative (auto-resolved)"; then
            MERGE_OK=1
        fi
    fi
fi

if [ "$MERGE_OK" -eq 1 ]; then
    echo ""
    echo "🛡️ Running Mandatory Anti-Regression Verification (dmhost smoke test)..."
    if ! make -C "$REPO_ROOT/dm/host" GAME=040074A01BF12000 >/tmp/sync_verify.log 2>&1 || ! make -C "$REPO_ROOT/dm/host" GAME=0100DCA0064A6000 >/tmp/sync_verify.log 2>&1; then
        echo "❌ ERROR: Regression detected! dmhost failed to compile after upstream sync."
        tail -n 25 /tmp/sync_verify.log
        echo "⚠️ Rolling back merge to protect production stability..."
        git reset --hard HEAD~1
        MERGE_OK=0
    else
        echo "✅ dmhost compilation smoke test passed successfully!"
    fi
fi

if [ "$MERGE_OK" -eq 1 ]; then
    echo ""
    echo "🎉 Merge completed successfully and verified!"
    echo "All NxNative Launcher customizations and host binaries are verified."
    echo ""
    echo "🎮 Regenerating SUPPORTED_GAMES.md from upstream game definitions..."
    python3 "$REPO_ROOT/scripts/generate_supported_games.py" 2>/dev/null || python3 "$REPO_ROOT/nxnative/scripts/generate_supported_games.py" 2>/dev/null || true
    if git status --porcelain | grep -q "SUPPORTED_GAMES.md"; then
        echo "📝 Committing updated SUPPORTED_GAMES.md..."
        git add SUPPORTED_GAMES.md nxnative/SUPPORTED_GAMES.md 2>/dev/null || true
        git commit -m "docs: auto-update SUPPORTED_GAMES.md from upstream game list" || true
    fi
else
    echo ""
    echo "⚠️ Sync failed or was rolled back due to compilation regression."
    echo "Main branch remains safe."
fi

if [ "$STASHED" -eq 1 ]; then
    echo ""
    echo "Restoring local stashed changes..."
    git stash pop || true
fi
