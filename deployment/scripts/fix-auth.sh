#!/bin/bash

# Google Cloud Authentication Fix Script
# This script fixes common authentication issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if gcloud is installed
check_gcloud() {
    if ! command -v gcloud &> /dev/null; then
        log_error "Google Cloud SDK is not installed. Please install it first:"
        echo "  curl https://sdk.cloud.google.com | bash"
        exit 1
    fi
    
    log_info "Google Cloud SDK is installed"
}

# Clear existing authentication
clear_auth() {
    log_info "Clearing existing authentication..."
    
    # Revoke all existing credentials
    gcloud auth revoke --all 2>/dev/null || true
    
    # Clear application default credentials
    rm -f ~/.config/gcloud/application_default_credentials.json 2>/dev/null || true
    rm -f ~/.config/gcloud/legacy_credentials 2>/dev/null || true
    
    log_success "Authentication cleared"
}

# Authenticate user
authenticate_user() {
    log_info "Authenticating user account..."
    
    # Login with user account
    gcloud auth login --no-launch-browser
    
    log_success "User authentication completed"
}

# Set up application default credentials
setup_adc() {
    log_info "Setting up Application Default Credentials..."
    
    # Set up application default credentials
    gcloud auth application-default login --no-launch-browser
    
    log_success "Application Default Credentials configured"
}

# Get project configuration
get_project_id() {
    if [ -f "deployment/terraform/terraform.tfvars" ]; then
        PROJECT_ID=$(grep "^project_id" deployment/terraform/terraform.tfvars | cut -d'"' -f2)
        if [ -z "$PROJECT_ID" ]; then
            log_error "project_id not found in terraform.tfvars"
            exit 1
        fi
    else
        log_error "terraform.tfvars not found. Please create it first:"
        echo "  cp deployment/terraform/terraform.tfvars.example deployment/terraform/terraform.tfvars"
        echo "  # Edit with your project ID"
        exit 1
    fi
    
    log_info "Using project ID: $PROJECT_ID"
}

# Set project and verify access
set_project() {
    log_info "Setting active project to: $PROJECT_ID"
    
    # Set the project
    gcloud config set project "$PROJECT_ID"
    
    # Verify access
    log_info "Verifying project access..."
    if ! gcloud projects describe "$PROJECT_ID" &>/dev/null; then
        log_error "Cannot access project $PROJECT_ID. Please check:"
        echo "  1. Project ID is correct"
        echo "  2. You have access to the project"
        echo "  3. Billing is enabled for the project"
        exit 1
    fi
    
    log_success "Project access verified"
}

# Enable required APIs manually (fallback)
enable_apis_manual() {
    log_info "Enabling required APIs manually..."
    
    local apis=(
        "run.googleapis.com"
        "cloudbuild.googleapis.com"
        "sql-component.googleapis.com"
        "sqladmin.googleapis.com"
        "redis.googleapis.com"
        "storage-component.googleapis.com"
        "secretmanager.googleapis.com"
        "artifactregistry.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        log_info "Enabling $api..."
        if gcloud services enable "$api" --quiet; then
            log_success "$api enabled"
        else
            log_warning "Failed to enable $api - may already be enabled"
        fi
    done
}

# Test authentication
test_auth() {
    log_info "Testing authentication..."
    
    # Test user authentication
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
        log_success "Active account: $ACTIVE_ACCOUNT"
    else
        log_error "No active authentication found"
        return 1
    fi
    
    # Test application default credentials
    if gcloud auth application-default print-access-token &>/dev/null; then
        log_success "Application Default Credentials working"
    else
        log_error "Application Default Credentials not working"
        return 1
    fi
    
    # Test project access
    if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
        log_success "Project access working"
    else
        log_error "Cannot access project $PROJECT_ID"
        return 1
    fi
}

# Main execution
main() {
    echo "============================================="
    echo "Google Cloud Authentication Fix"
    echo "============================================="
    
    check_gcloud
    get_project_id
    
    echo ""
    log_warning "This will clear all existing Google Cloud authentication"
    read -p "Do you want to continue? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        log_info "Authentication fix cancelled"
        exit 0
    fi
    
    clear_auth
    authenticate_user
    setup_adc
    set_project
    
    # Test if everything works
    if test_auth; then
        log_success "Authentication setup completed successfully!"
        echo ""
        log_info "You can now retry the infrastructure deployment:"
        echo "  ./deployment/scripts/deploy-infrastructure.sh"
    else
        log_error "Authentication setup failed. Manual steps required:"
        echo ""
        echo "1. Enable APIs manually in Google Cloud Console:"
        echo "   https://console.cloud.google.com/apis/library?project=$PROJECT_ID"
        echo ""
        echo "2. Or try enabling APIs manually:"
        enable_apis_manual
        echo ""
        echo "3. Then retry the deployment"
    fi
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
