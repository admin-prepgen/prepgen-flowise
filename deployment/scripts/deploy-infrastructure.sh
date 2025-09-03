#!/bin/bash

# Flowise Cloud Run Infrastructure Deployment Script
# This script sets up the infrastructure using Terraform

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

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        log_error "Google Cloud SDK is not installed. Please install gcloud first."
        exit 1
    fi
    
    log_success "All dependencies are installed"
}

# Validate configuration
validate_config() {
    log_info "Validating configuration..."
    
    if [ ! -f "deployment/terraform/terraform.tfvars" ]; then
        log_error "terraform.tfvars not found. Please copy terraform.tfvars.example to terraform.tfvars and update it."
        exit 1
    fi
    
    # Check if required variables are set
    if ! grep -q "^project_id" deployment/terraform/terraform.tfvars; then
        log_error "project_id is not set in terraform.tfvars"
        exit 1
    fi
    
    log_success "Configuration validated"
}

# Initialize Terraform
init_terraform() {
    log_info "Initializing Terraform..."
    cd deployment/terraform
    terraform init
    cd ../..
    log_success "Terraform initialized"
}

# Plan Terraform deployment
plan_terraform() {
    log_info "Planning Terraform deployment..."
    cd deployment/terraform
    terraform plan
    cd ../..
    log_success "Terraform plan completed"
}

# Apply Terraform deployment
apply_terraform() {
    log_info "Applying Terraform deployment..."
    cd deployment/terraform
    terraform apply -auto-approve
    cd ../..
    log_success "Infrastructure deployed successfully"
}

# Display outputs
show_outputs() {
    log_info "Deployment outputs:"
    cd deployment/terraform
    terraform output
    cd ../..
}

# Main execution
main() {
    echo "========================================="
    echo "Flowise Cloud Run Infrastructure Setup"
    echo "========================================="
    
    check_dependencies
    validate_config
    
    # Authenticate with Google Cloud
    log_info "Checking Google Cloud authentication..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_warning "Not authenticated with Google Cloud. Please run: gcloud auth login"
        exit 1
    fi
    
    # Set the project
    PROJECT_ID=$(grep "^project_id" deployment/terraform/terraform.tfvars | cut -d'"' -f2)
    log_info "Setting GCP project to: $PROJECT_ID"
    gcloud config set project "$PROJECT_ID"
    
    init_terraform
    plan_terraform
    
    # Confirm deployment
    echo ""
    log_warning "This will create infrastructure in GCP project: $PROJECT_ID"
    read -p "Do you want to continue? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    apply_terraform
    show_outputs
    
    echo ""
    log_success "Infrastructure deployment completed!"
    log_info "Next steps:"
    echo "  1. Run './deployment/scripts/setup-secrets.sh' to configure Secret Manager"
    echo "  2. Run './deployment/scripts/deploy-application.sh' to deploy the application"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
