#!/bin/bash

# Voron Config Backup with Simple Configuration File
# Reads all settings from ~/.voron-backup-config

CONFIG_FILE="$HOME/.voron-backup-config"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    echo ""
    echo "Please create the configuration file with your settings."
    echo "See the documentation for the required format."
    exit 1
fi

# Load configuration (simple and reliable)
echo "Loading configuration from $CONFIG_FILE..."
set -a  # automatically export all variables
source "$CONFIG_FILE"
set +a  # stop auto-exporting

# Expand tilde in paths
CONFIG_FOLDER=$(eval echo "${CONFIG_FOLDER:-~/printer_data/config}")
KLIPPER_FOLDER=$(eval echo "${KLIPPER_FOLDER:-~/klipper}")
MOONRAKER_FOLDER=$(eval echo "${MOONRAKER_FOLDER:-~/moonraker}")
MAINSAIL_FOLDER=$(eval echo "${MAINSAIL_FOLDER:-~/mainsail}")
FLUIDD_FOLDER=$(eval echo "${FLUIDD_FOLDER:-~/fluidd}")
DATABASE_FILE=$(eval echo "${DATABASE_FILE:-~/printer_data/database/moonraker-sql.db}")

# Set defaults for optional settings
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
GIT_USER_NAME="${GIT_USER_NAME:-Voron-Backup-Bot}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-voron-backup-bot@noreply.github.com}"
BACKUP_DATABASE="${BACKUP_DATABASE:-true}"
VERBOSE_OUTPUT="${VERBOSE_OUTPUT:-false}"

# Lock file to prevent simultaneous runs
LOCK_FILE="$CONFIG_FOLDER/.backup_lock"

# Cleanup function
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# Verbose logging function
log() {
    if [ "$VERBOSE_OUTPUT" = "true" ]; then
        echo "$1"
    fi
}

# Check for simultaneous runs
if [ -f "$LOCK_FILE" ]; then
    echo "Backup already running (lock file exists)"
    exit 1
fi
touch "$LOCK_FILE"

# Validate critical paths and credentials
if [ ! -d "$CONFIG_FOLDER" ]; then
    echo "ERROR: Config folder not found: $CONFIG_FOLDER"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_REPO" ]; then
    echo "ERROR: GitHub credentials not set in configuration file"
    echo "Please update $CONFIG_FILE with your GitHub token and repository"
    exit 1
fi

log "Configuration loaded successfully:"
log "  Config folder: $CONFIG_FOLDER"
log "  GitHub repo: $GITHUB_REPO"
log "  Branch: $GITHUB_BRANCH"

# Get version information (with error handling)
grab_version(){
    m1="" m2="" m3="" m4=""

    if [ ! -z "$KLIPPER_FOLDER" ] && [ -d "$KLIPPER_FOLDER" ]; then
        klipper_commit=$(git -C "$KLIPPER_FOLDER" describe --always --tags --long 2>/dev/null | awk '{gsub(/^ +| +$/,"")} {print $0}')
        [ ! -z "$klipper_commit" ] && m1="Klipper version: $klipper_commit"
        log "Found Klipper: $klipper_commit"
    fi

    if [ ! -z "$MOONRAKER_FOLDER" ] && [ -d "$MOONRAKER_FOLDER" ]; then
        moonraker_commit=$(git -C "$MOONRAKER_FOLDER" describe --always --tags --long 2>/dev/null | awk '{gsub(/^ +| +$/,"")} {print $0}')
        [ ! -z "$moonraker_commit" ] && m2="Moonraker version: $moonraker_commit"
        log "Found Moonraker: $moonraker_commit"
    fi

    if [ ! -z "$MAINSAIL_FOLDER" ] && [ -f "$MAINSAIL_FOLDER/.version" ]; then
        mainsail_ver=$(head -n 1 "$MAINSAIL_FOLDER/.version" 2>/dev/null)
        [ ! -z "$mainsail_ver" ] && m3="Mainsail version: $mainsail_ver"
        log "Found Mainsail: $mainsail_ver"
    fi

    if [ ! -z "$FLUIDD_FOLDER" ] && [ -f "$FLUIDD_FOLDER/.version" ]; then
        fluidd_ver=$(head -n 1 "$FLUIDD_FOLDER/.version" 2>/dev/null)
        [ ! -z "$fluidd_ver" ] && m4="Fluidd version: $fluidd_ver"
        log "Found Fluidd: $fluidd_ver"
    fi
}

# Copy database for backup (with error handling)
if [ "$BACKUP_DATABASE" = "true" ] && [ -f "$DATABASE_FILE" ]; then
    echo "SQLite history database found! Copying..."
    if cp "$DATABASE_FILE" "$CONFIG_FOLDER/" 2>/dev/null; then
        echo "Database backup successful"
    else
        echo "WARNING: Failed to copy database"
    fi
else
    log "Database backup skipped or file not found"
fi

# Push configuration (with error handling)
push_config(){
    cd "$CONFIG_FOLDER" || {
        echo "ERROR: Cannot access config folder"
        exit 1
    }

    # Initialize git if needed
    if [ ! -d ".git" ]; then
        echo "Initializing git repository..."
        git init -b "$GITHUB_BRANCH"
    fi
    
    # Always set git user configuration
    git config user.name "$GIT_USER_NAME"
    git config user.email "$GIT_USER_EMAIL"

    # Set up or update remote URL with token
    if git remote get-url origin >/dev/null 2>&1; then
        git remote set-url origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git"
    else
        git remote add origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git"
    fi
    
    # Set up branch tracking
    git branch --set-upstream-to=origin/"$GITHUB_BRANCH" "$GITHUB_BRANCH" 2>/dev/null || true

    # Pull with error handling
    echo "Pulling latest changes..."
    if ! git pull origin "$GITHUB_BRANCH" --no-rebase 2>/dev/null; then
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
    if git push origin "$GITHUB_BRANCH"; then
        echo "✅ Backup completed successfully!"
    else
        echo "❌ ERROR: Push failed - backup not completed"
        exit 1
    fi
}

grab_version
push_config

