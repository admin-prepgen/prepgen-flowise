#!/bin/bash

# Flowise Cloud Run Infrastructure Deployment Script
# This script sets up the infrastructure using Terraform

set -e

# Colors for output
RED='[0;31m'
GREEN='[0;32m'
BLUE='[0;34m'
YELLOW='[1;33m'
NC='[0m' # No Color

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

# Usage
usage() {
    echo "Usage: $0 [stg|prd]"
    echo "Deploys the infrastructure to the specified environment."
    echo "If no environment is specified, it defaults to 'stg'."
    exit 1
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
    local env=$1
    local tfvars_file="deployment/terraform/terraform.tfvars.${env}"

    log_info "Validating configuration for ${env} environment..."
    
    if [ ! -f "${tfvars_file}" ]; then
        log_error "${tfvars_file} not found. Please make sure the environment is set up correctly."
        exit 1
    fi
    
    # Check if required variables are set
    if ! grep -q "^project_id" "${tfvars_file}"; then
        log_error "project_id is not set in ${tfvars_file}"
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
    local env=$1
    log_info "Planning Terraform deployment for ${env} environment..."
    cd deployment/terraform
    terraform plan -var-file="terraform.tfvars.${env}"
    cd ../..
    log_success "Terraform plan completed"
}

# Apply Terraform deployment
apply_terraform() {
    local env=$1
    log_info "Applying Terraform deployment for ${env} environment..."
    cd deployment/terraform
    terraform apply -var-file="terraform.tfvars.${env}" -auto-approve
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
    local env="stg" # Default environment
    if [ -n "$1" ]; then
        if [ "$1" == "stg" ] || [ "$1" == "prd" ]; then
            env=$1
        else
            usage
        fi
    fi

    echo "========================================="
    echo "Flowise Cloud Run Infrastructure Setup"
    echo "========================================="
    
    check_dependencies
    validate_config "${env}"
    
    # Authenticate with Google Cloud
    log_info "Checking Google Cloud authentication..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_warning "Not authenticated with Google Cloud. Please run: gcloud auth login"
        exit 1
    fi
    
    # Set the project
    PROJECT_ID=$(grep "^project_id" "deployment/terraform/terraform.tfvars.${env}" | cut -d'"' -f2)
    log_info "Setting GCP project to: $PROJECT_ID"
    gcloud config set project "$PROJECT_ID"
    
    init_terraform
    plan_terraform "${env}"
    
    # Confirm deployment
    echo ""
    log_warning "This will create infrastructure in GCP project: $PROJECT_ID"
    read -p "Do you want to continue? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    apply_terraform "${env}"
    show_outputs
    
    echo ""
    log_success "Infrastructure deployment completed!"
    log_info "Next steps:"
    echo "  1. Run './deployment/scripts/setup-secrets.sh' to configure Secret Manager"
    echo "  2. Run './deployment/scripts/deploy-application.sh ${env}' to deploy the application"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi