#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

# Check if git repo argument is provided
if [ -z "$1" ]; then
    print_error "Git repository URL is required!"
    echo "Usage: curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/runner.sh | bash -s -- YOUR_GIT_REPO_URL"
    exit 1
fi

GIT_REPO=$1

print_info "Starting deployment process..."

# Install ca-certificates first (fixes curl SSL errors)
print_info "Installing CA certificates..."
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get update -qq
sudo -E apt-get install -y ca-certificates -qq
print_success "CA certificates installed"

# Update system
print_info "Updating system packages..."
sudo -E apt-get update -qq

# Install Git
print_info "Installing Git..."
sudo -E apt-get install -y git curl -qq
print_success "Git installed"

# Install NVM
print_info "Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

print_success "NVM installed"

# Install Node.js 22
print_info "Installing Node.js 22..."
nvm install 22
nvm use 22
nvm alias default 22
print_success "Node.js 22 installed and set as default"

# Install PostgreSQL
print_info "Installing PostgreSQL..."
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get install -y postgresql postgresql-contrib -qq
sudo systemctl start postgresql
sudo systemctl enable postgresql
print_success "PostgreSQL installed"

# Create PostgreSQL user
print_info "Creating PostgreSQL user 'creator'..."
sudo -u postgres psql -c "CREATE USER creator WITH PASSWORD 'root';" 2>/dev/null || print_info "User already exists"
sudo -u postgres psql -c "ALTER USER creator WITH SUPERUSER;"
sudo -u postgres psql -c "ALTER USER creator WITH CREATEDB;"
sudo -u postgres psql -c "ALTER USER creator WITH CREATEROLE;"
sudo -u postgres psql -c "ALTER USER creator WITH REPLICATION;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE postgres TO creator;"
print_success "PostgreSQL user 'creator' created with full permissions"

# Install PM2
print_info "Installing PM2..."
npm install -g pm2
print_success "PM2 installed"

# Generate random folder name
RANDOM_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w $(shuf -i 5-15 -n 1) | head -n 1)
SOURCE_FOLDER="source-runner-${RANDOM_SUFFIX}"

print_info "Source folder: $SOURCE_FOLDER"

# Clone repository
print_info "Cloning repository..."
git clone "$GIT_REPO" "$SOURCE_FOLDER"

if [ $? -ne 0 ]; then
    print_error "Failed to clone repository"
    exit 1
fi

print_success "Repository cloned"

# Change to source folder
cd "$SOURCE_FOLDER"

# Install dependencies
print_info "Installing npm dependencies..."
npm install

if [ $? -ne 0 ]; then
    print_error "Failed to install dependencies"
    exit 1
fi

print_success "Dependencies installed"
print_success "Prisma DB PUSH..."
npx prisma db push
print_success "Prisma DB PUSH... End"
# Ask for Telegram bot token
print_info "Please enter your Telegram bot TOKEN:"
read -r TOKEN < /dev/tty

# Create .env file
print_info "Creating .env file..."
cat > .env << EOF
TOKEN=$TOKEN
EOF

print_success ".env file created"

# Start with PM2
print_info "Starting application with PM2..."
pm2 start npm --name "$SOURCE_FOLDER" -- run start

if [ $? -ne 0 ]; then
    print_error "Failed to start application"
    exit 1
fi

print_success "Application started!"

# Save PM2 process list
pm2 save

# Setup PM2 to start on boot
print_info "Setting up PM2 startup..."
pm2 startup systemd -u $USER --hp $HOME
sudo env PATH=$PATH:/home/$USER/.nvm/versions/node/$(node -v)/bin pm2 startup systemd -u $USER --hp $HOME

print_success "Deployment completed successfully!"
echo ""
print_info "Application is running as: $SOURCE_FOLDER"
print_info "View logs with: pm2 logs $SOURCE_FOLDER"
print_info "View status with: pm2 status"
print_info "Stop app with: pm2 stop $SOURCE_FOLDER"
print_info "Restart app with: pm2 restart $SOURCE_FOLDER"
