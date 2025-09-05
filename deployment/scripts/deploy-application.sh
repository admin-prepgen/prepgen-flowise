#!/bin/bash

# Flowise Cloud Run Application Deployment Script
# This script builds and deploys the application to Cloud Run

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
    echo "Deploys the application to the specified environment."
    echo "If no environment is specified, it defaults to 'stg'."
    exit 1
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v gcloud &> /dev/null; then
        log_error "Google Cloud SDK is not installed. Please install gcloud first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    log_success "All dependencies are installed"
}

# Get project configuration
get_config() {
    local env=$1
    local tfvars_file="deployment/terraform/terraform.tfvars.${env}"

    if [ -f "${tfvars_file}" ]; then
        PROJECT_ID=$(grep "^project_id" "${tfvars_file}" | cut -d'"' -f2)
        REGION=$(grep "^region" "${tfvars_file}" | cut -d'"' -f2 || echo "us-central1")
    else
        log_error "${tfvars_file} not found. Please make sure the environment is set up correctly."
        exit 1
    fi
    
    REPOSITORY="flowise-repo"
    REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}"
}

# Authenticate Docker with Artifact Registry
setup_docker_auth() {
    log_info "Setting up Docker authentication with Artifact Registry..."
    gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
    log_success "Docker authentication configured"
}

# Build and push images using Cloud Build
build_and_deploy() {
    log_info "Starting Cloud Build deployment..."
    
    # Submit build to Cloud Build
    gcloud builds submit \
        --config=deployment/cloudbuild.yaml \
        --substitutions=_REGION="${REGION}",_REPOSITORY="${REPOSITORY}" \
        .
    
    log_success "Cloud Build deployment completed"
}

# Update Cloud Run services with secrets
update_services_with_secrets() {
    log_info "Updating Cloud Run services with secret configurations..."
    
    # Update main service
    log_info "Updating flowise-main service..."
    gcloud run services update flowise-main \
        --region="${REGION}" \
        --update-secrets="DATABASE_HOST=flowise-db-host:latest" \
        --update-secrets="DATABASE_NAME=flowise-db-name:latest" \
        --update-secrets="DATABASE_USER=flowise-db-user:latest" \
        --update-secrets="DATABASE_PASSWORD=flowise-db-password:latest" \
        --update-secrets="REDIS_HOST=flowise-redis-host:latest" \
        --update-secrets="REDIS_PASSWORD=flowise-redis-password:latest" \
        --update-secrets="JWT_AUTH_TOKEN_SECRET=flowise-jwt-token-secret:latest" \
        --update-secrets="JWT_REFRESH_TOKEN_SECRET=flowise-jwt-refresh-token-secret:latest" \
        --quiet
    
    # Update worker service
    log_info "Updating flowise-worker service..."
    gcloud run services update flowise-worker \
        --region="${REGION}" \
        --update-secrets="DATABASE_HOST=flowise-db-host:latest" \
        --update-secrets="DATABASE_NAME=flowise-db-name:latest" \
        --update-secrets="DATABASE_USER=flowise-db-user:latest" \
        --update-secrets="DATABASE_PASSWORD=flowise-db-password:latest" \
        --update-secrets="REDIS_HOST=flowise-redis-host:latest" \
        --update-secrets="REDIS_PASSWORD=flowise-redis-password:latest" \
        --quiet
    
    log_success "Services updated with secrets"
}

# Get service URLs
get_service_urls() {
    log_info "Getting service URLs..."
    
    MAIN_URL=$(gcloud run services describe flowise-main --region="${REGION}" --format="value(status.url)")
    
    echo ""
    log_success "Deployment completed successfully!"
    echo ""
    echo "Service URLs:"
    echo "  Main Application: ${MAIN_URL}"
    echo ""
    echo "Access your Flowise installation at: ${MAIN_URL}"
}

# Setup monitoring and logging
setup_monitoring() {
    log_info "Setting up monitoring and logging..."
    
    # Enable Cloud Run logging
    log_info "Cloud Run logging is enabled by default"
    
    # You can add custom monitoring setup here if needed
    log_success "Monitoring setup completed"
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

    echo "==========================================="
    echo "Flowise Cloud Run Application Deployment"
    echo "==========================================="
    
    check_dependencies
    get_config "${env}"
    
    log_info "Deploying to project: ${PROJECT_ID}"
    log_info "Region: ${REGION}"
    log_info "Registry: ${REGISTRY}"
    
    # Authenticate with Google Cloud
    log_info "Checking Google Cloud authentication..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_warning "Not authenticated with Google Cloud. Please run: gcloud auth login"
        exit 1
    fi
    
    # Set the project
    gcloud config set project "${PROJECT_ID}"
    
    setup_docker_auth
    
    # Confirm deployment
    echo ""
    log_warning "This will build and deploy the application to Cloud Run in the '${env}' environment."
    read -p "Do you want to continue? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    build_and_deploy
    update_services_with_secrets
    setup_monitoring
    get_service_urls
    
    echo ""
    log_info "Post-deployment steps:"
    echo "  1. Configure your DNS to point to the Cloud Run URL (optional)"
    echo "  2. Set up SSL certificate for custom domain (optional)"
    echo "  3. Configure monitoring alerts (optional)"
    echo ""
    log_success "Application deployment completed successfully!"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi