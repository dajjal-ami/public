#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ${GREEN}$1${NC}"
}

error() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ${RED}Error: $1${NC}"
    exit 1
}

# Check if git URL is provided
if [ -z "$1" ]; then
    error "Git repository URL is required"
fi

REPO_URL=$1

# Install nvm if not present
log "Installing/updating nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js 22
log "Installing Node.js v22..."
nvm install 22 || error "Failed to install Node.js"
nvm use 22 || error "Failed to use Node.js v22"

# Clone repository
log "Cloning repository..."
git clone "$REPO_URL" token || error "Failed to clone repository"

# Navigate to project directory
cd token || error "Failed to enter project directory"

# Install dependencies
log "Installing dependencies..."
npm install || error "Failed to install dependencies"

# Build project
log "Building project..."
npm run build || error "Failed to build project"

# Start project with interactive mode
log "Starting project in interactive mode..."
exec npm run start
