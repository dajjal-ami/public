#!/bin/bash

# Colors for beautiful output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display success message
success_message() {
    echo -e "${GREEN}$1${NC}"
}

# Function to display error message
error_message() {
    echo -e "${RED}$1${NC}"
}

# Function to display info message
info_message() {
    echo -e "${YELLOW}$1${NC}"
}

# Function to display step message
step_message() {
    echo -e "${BLUE}$1${NC}"
}

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
  error_message "Please run as root (use sudo)"
  exit 1
fi

# Check if the Git URL is provided
if [ -z "$1" ]; then
  error_message "Usage: $0 <git-repo-url>"
  exit 1
fi

giturl="$1"

# Check if the URL ends with .git
if [[ ! "$giturl" =~ \.git$ ]]; then
  error_message "Error: The repository URL must end with '.git'"
  exit 1
fi

# Starting setup
info_message "Starting setup for tact-tool..."

# Installing Git
step_message "Step 1: Installing Git..."
sudo apt update > /dev/null 2>&1
sudo apt install git -y > /dev/null 2>&1
success_message "Git installed successfully!"

# Cloning the repository
step_message "Step 2: Cloning the repository from $giturl..."
git clone "$giturl" dodo-coin > /dev/null 2>&1
if [ $? -eq 0 ]; then
  success_message "Repository cloned successfully!"
else
  error_message "Error cloning the repository. Check the URL."
  exit 1
fi

# Installing NVM and Node.js
step_message "Step 6: Installing NVM and Node.js..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash > /dev/null 2>&1
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
source ~/.bashrc
nvm install 22 > /dev/null 2>&1
nvm use 22 > /dev/null 2>&1
success_message "NVM and Node.js installed successfully!"

# Installing PM2
step_message "Step 7: Installing PM2..."
npm install -g pm2 > /dev/null 2>&1
success_message "PM2 installed successfully!"

step_message "installing dependencies..."
npm install
success_message "Project dependencies installed successfully!"

# Starting the project with PM2
step_message "Step 11: Starting the project with PM2..."
npx pm2 start npm --name "tact-tool" -- run start
npx pm2 save
npx pm2 startup
npx pm2 stop tact-tool
success_message "Project startup with PM2!"

# Ensure interactive input works for node script
step_message "Running variable_setup.js..."
exec < /dev/tty && node variable_setup.js && exec <&-
