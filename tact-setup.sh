#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ${GREEN}$1${NC}"
}

warn() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ${YELLOW}Warning: $1${NC}"
}

error() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ${RED}Error: $1${NC}"
    exit 1
}

# Function to check command status
check_status() {
    if [ $? -ne 0 ]; then
        error "$1"
    fi
}

# Check if git URL is provided and valid
if [ -z "$1" ]; then
    error "Git repository URL is required"
fi

if [[ ! "$1" =~ ^https?://[^/]+/[^/]+/[^/]+(.git)?$ ]]; then
    error "Invalid git repository URL format"
fi

REPO_URL=$1

# Check internet connectivity
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    error "No internet connection detected"
fi

# Check and install git if needed
if ! command -v git &> /dev/null; then
    log "Git not found. Installing git..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            apt-get update || error "Failed to update package list"
            apt-get install -y git || error "Failed to install git"
        elif command -v yum &> /dev/null; then
            yum install -y git || error "Failed to install git"
        else
            error "Unsupported Linux distribution. Please install git manually."
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install git || error "Failed to install git via Homebrew"
        else
            error "Homebrew not found. Please install Homebrew or git manually."
        fi
    else
        error "Unsupported operating system. Please install git manually."
    fi
fi

# Verify git installation
git --version || error "Git installation verification failed"

# Check if token directory already exists
if [ -d "token" ]; then
    error "Directory 'token' already exists. Please remove or rename it"
fi

# Install nvm if not present
log "Installing/updating nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
check_status "Failed to install nvm"

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
if ! command -v nvm &> /dev/null; then
    error "Failed to load nvm. Please restart your terminal and try again"
fi

# Install Node.js 22
log "Installing Node.js v22..."
nvm install 22
check_status "Failed to install Node.js"

nvm use 22
check_status "Failed to use Node.js v22"

# Verify node and npm installation
node --version || error "Node.js installation verification failed"
npm --version || error "npm installation verification failed"

# Clone repository
log "Cloning repository..."
git clone "$REPO_URL" token
check_status "Failed to clone repository"

# Navigate to project directory
cd token || error "Failed to enter project directory"

# Check if package.json exists
if [ ! -f "package.json" ]; then
    error "package.json not found in the repository"
fi

# Check required npm scripts exist
if ! grep -q '"build"' package.json; then
    error "Build script not found in package.json"
fi

if ! grep -q '"start"' package.json; then
    error "Start script not found in package.json"
fi

# Clear npm cache if exists
log "Clearing npm cache..."
npm cache clean --force
check_status "Failed to clean npm cache"

# Install dependencies
log "Installing dependencies..."
# First try with no optional dependencies
npm i --no-optional || {
    warn "Failed to install with --no-optional, trying with full install..."
    npm i
}
check_status "Failed to install dependencies"

# Verify node_modules exists
if [ ! -d "node_modules" ]; then
    error "node_modules directory not found after installation"
fi

# Build project
log "Building project..."
npm run build
check_status "Failed to build project"

# Check if process is already running on default ports
if netstat -tln | grep -q ':3000\|:8080\|:5000'; then
    warn "Common ports (3000/8080/5000) might be in use. This could cause issues."
fi

# Check disk space before starting
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}')
log "Available disk space: $AVAILABLE_SPACE"

# Start project with interactive mode
log "Starting project in interactive mode..."
# Using exec to properly handle SIGTERM and other signals
exec npm run start
