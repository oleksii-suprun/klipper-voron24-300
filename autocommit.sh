#!/bin/bash

# Simple Voron Config Backup - KISS Version with Safety Improvements
# Maintains same functionality as original autocommit.sh but safer

# Configuration (edit as needed)
config_folder=~/printer_data/config
klipper_folder=~/klipper
moonraker_folder=~/moonraker
mainsail_folder=~/mainsail
fluidd_folder=~/fluidd
branch=main
db_file=~/printer_data/database/moonraker-sql.db

# GitHub credentials from environment variables (more secure)
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_REPO="${GITHUB_REPO:-}"

# Lock file to prevent simultaneous runs
LOCK_FILE="$config_folder/.backup_lock"

# Cleanup function
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# Check for simultaneous runs
if [ -f "$LOCK_FILE" ]; then
    echo "Backup already running (lock file exists)"
    exit 1
fi
touch "$LOCK_FILE"

# Validate critical paths and credentials
if [ ! -d "$config_folder" ]; then
    echo "ERROR: Config folder not found: $config_folder"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_REPO" ]; then
    echo "ERROR: GitHub credentials not set"
    echo "Set environment variables:"
    echo "  export GITHUB_TOKEN='ghp_your_token'"
    echo "  export GITHUB_REPO='username/repo-name'"
    exit 1
fi

# Get version information (with error handling)
grab_version(){
    m1="" m2="" m3="" m4=""

    if [ ! -z "$klipper_folder" ] && [ -d "$klipper_folder" ]; then
        klipper_commit=$(git -C "$klipper_folder" describe --always --tags --long 2>/dev/null | awk '{gsub(/^ +| +$/,"")} {print $0}')
        [ ! -z "$klipper_commit" ] && m1="Klipper version: $klipper_commit"
    fi

    if [ ! -z "$moonraker_folder" ] && [ -d "$moonraker_folder" ]; then
        moonraker_commit=$(git -C "$moonraker_folder" describe --always --tags --long 2>/dev/null | awk '{gsub(/^ +| +$/,"")} {print $0}')
        [ ! -z "$moonraker_commit" ] && m2="Moonraker version: $moonraker_commit"
    fi

    if [ ! -z "$mainsail_folder" ] && [ -f "$mainsail_folder/.version" ]; then
        mainsail_ver=$(head -n 1 "$mainsail_folder/.version" 2>/dev/null)
        [ ! -z "$mainsail_ver" ] && m3="Mainsail version: $mainsail_ver"
    fi

    if [ ! -z "$fluidd_folder" ] && [ -f "$fluidd_folder/.version" ]; then
        fluidd_ver=$(head -n 1 "$fluidd_folder/.version" 2>/dev/null)
        [ ! -z "$fluidd_ver" ] && m4="Fluidd version: $fluidd_ver"
    fi
}

# Copy database for backup (with error handling)
if [ -f "$db_file" ]; then
    echo "SQLite history database found! Copying..."
    if cp "$db_file" "$config_folder/" 2>/dev/null; then
        echo "Database backup successful"
    else
        echo "WARNING: Failed to copy database"
    fi
else
    echo "SQLite history database not found"
fi

# Push configuration (with error handling)
push_config(){
    cd "$config_folder" || {
        echo "ERROR: Cannot access config folder"
        exit 1
    }

    # Initialize git if needed
    if [ ! -d ".git" ]; then
        echo "Initializing git repository..."
        git init -b main
        git config user.name "Voron-Backup-Bot"
        git config user.email "voron-backup-bot@noreply.github.com"
    fi

    # Set up or update remote URL with token from environment
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git"

    # Pull with error handling
    echo "Pulling latest changes..."
    if ! git pull origin "$branch" --no-rebase 2>/dev/null; then
        echo "WARNING: Git pull failed, continuing with backup"
        # Check for merge conflicts
        if git status --porcelain | grep -q "^UU\|^AA\|^DD"; then
            echo "ERROR: Merge conflicts detected. Manual intervention required."
            exit 1
        fi
    fi

    # Add all changes
    git add .

    # Check if there are actually changes to commit
    if git diff --staged --quiet; then
        echo "No changes to backup"
        exit 0
    fi

    # Create commit
    current_date=$(date +"%Y-%m-%d %T")
    echo "Creating commit..."

    # Build commit message (only add non-empty version info)
    commit_args=(-m "🤖 Autocommit from $current_date")
    [ ! -z "$m1" ] && commit_args+=(-m "$m1")
    [ ! -z "$m2" ] && commit_args+=(-m "$m2")
    [ ! -z "$m3" ] && commit_args+=(-m "$m3")
    [ ! -z "$m4" ] && commit_args+=(-m "$m4")

    if git commit "${commit_args[@]}"; then
        echo "Commit successful"
    else
        echo "ERROR: Commit failed"
        exit 1
    fi

    # Push with error handling
    echo "Pushing to GitHub..."
    if git push origin "$branch"; then
        echo "✅ Backup completed successfully!"
    else
        echo "❌ ERROR: Push failed - backup not completed"
        exit 1
    fi
}

grab_version
push_config
