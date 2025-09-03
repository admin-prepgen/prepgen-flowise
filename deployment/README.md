# Flowise Cloud Run Deployment

This directory contains everything needed to deploy Flowise to Google Cloud Run as a scalable, serverless application.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Cloud Run     │    │    Cloud Run     │    │  Cloud SQL      │
│  (Main App)     │◄───┤   (Worker)       │◄───┤  (PostgreSQL)   │
│  Port: 3000     │    │  Port: 5566      │    │  Port: 5432     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Memorystore Redis                           │
│                    (Queue Management)                           │
└─────────────────────────────────────────────────────────────────┘
         ▲                        ▲
         │                        │
         ▼                        ▼
┌─────────────────┐    ┌──────────────────┐
│ Cloud Storage   │    │  Secret Manager  │
│ (File Storage)  │    │   (Secrets)      │
└─────────────────┘    └──────────────────┘
```

## 📁 Directory Structure

```
deployment/
├── README.md                           # This documentation
├── cloudbuild.yaml                     # Cloud Build configuration
├── .env.production.example             # Environment variables template
├── cloud-run/
│   ├── flowise-main-service.yaml       # Main service configuration
│   └── flowise-worker-service.yaml     # Worker service configuration
├── terraform/
│   ├── main.tf                         # Infrastructure as code
│   ├── variables.tf                    # Terraform variables
│   ├── outputs.tf                      # Terraform outputs
│   └── terraform.tfvars.example        # Terraform variables template
└── scripts/
    ├── deploy-infrastructure.sh        # Infrastructure deployment script
    └── deploy-application.sh           # Application deployment script
```

## 🚀 Quick Start

### Prerequisites

1. **Google Cloud SDK**: Install and authenticate
   ```bash
   # Install gcloud
   curl https://sdk.cloud.google.com | bash
   
   # Authenticate
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Terraform**: Install Terraform v1.0+
   ```bash
   # macOS
   brew install terraform
   
   # Or download from https://terraform.io/downloads
   ```

3. **Docker**: Install Docker (for local builds if needed)
   ```bash
   # macOS
   brew install docker
   ```

### Step 1: Configure Your Deployment

1. **Copy and configure Terraform variables:**
   ```bash
   cp deployment/terraform/terraform.tfvars.example deployment/terraform/terraform.tfvars
   ```
   
   Edit `terraform.tfvars` with your GCP project ID:
   ```hcl
   project_id = "your-gcp-project-id"
   region = "us-central1"                    # Optional
   db_tier = "db-f1-micro"                   # Optional
   redis_tier = "BASIC"                      # Optional
   redis_memory_size = 1                     # Optional
   environment = "prod"                      # Optional
   ```

2. **Copy and configure environment variables (optional):**
   ```bash
   cp deployment/.env.production.example deployment/.env.production
   ```
   
   Edit `.env.production` if you need to customize any settings.

### Step 2: Deploy Infrastructure

```bash
# Make scripts executable
chmod +x deployment/scripts/*.sh

# Deploy infrastructure (Cloud SQL, Redis, Storage, etc.)
./deployment/scripts/deploy-infrastructure.sh
```

This will:
- ✅ Enable required GCP APIs
- ✅ Create Artifact Registry repository
- ✅ Set up Cloud SQL PostgreSQL database
- ✅ Create Memorystore Redis instance
- ✅ Create Cloud Storage bucket
- ✅ Generate and store secrets in Secret Manager

### Step 3: Deploy Application

```bash
# Build and deploy the application
./deployment/scripts/deploy-application.sh
```

This will:
- ✅ Build Docker images using Cloud Build
- ✅ Deploy main service and worker service to Cloud Run
- ✅ Configure secrets and environment variables
- ✅ Set up health checks and monitoring

### Step 4: Access Your Application

After successful deployment, you'll see output similar to:
```
Service URLs:
  Main Application: https://flowise-main-xxxxx-uc.a.run.app

Access your Flowise installation at: https://flowise-main-xxxxx-uc.a.run.app
```

## ⚙️ Configuration Details

### Infrastructure Components

| Component | Description | Configuration |
|-----------|-------------|---------------|
| **Cloud Run (Main)** | Web interface and API | 2 vCPU, 2GB RAM, 0-10 instances |
| **Cloud Run (Worker)** | Background job processing | 2 vCPU, 2GB RAM, 1-5 instances |
| **Cloud SQL** | PostgreSQL database | db-f1-micro, 20GB SSD |
| **Memorystore Redis** | Queue management | Basic tier, 1GB memory |
| **Cloud Storage** | File upload storage | Regional bucket |
| **Secret Manager** | Secure credential storage | Auto-managed secrets |

### Environment Variables

Key environment variables are managed automatically:

| Variable | Source | Description |
|----------|--------|-------------|
| `DATABASE_*` | Secret Manager | Database connection details |
| `REDIS_*` | Secret Manager | Redis connection details |
| `JWT_*` | Secret Manager | Authentication secrets |
| `STORAGE_*` | Configuration | Cloud Storage settings |

### Scaling Configuration

- **Main Service**: Scales 0→10 instances based on traffic
- **Worker Service**: Runs 1→5 instances for background jobs
- **Auto-scaling**: Based on CPU and request metrics
- **Cold starts**: ~2-3 seconds for new instances

## 🔧 Customization Options

### Database Tiers

Modify `db_tier` in `terraform.tfvars`:
```hcl
# Development
db_tier = "db-f1-micro"      # 1 vCPU, 0.6GB RAM

# Production (small)
db_tier = "db-g1-small"      # 1 vCPU, 1.7GB RAM

# Production (medium)
db_tier = "db-custom-2-7680" # 2 vCPU, 7.5GB RAM
```

### Redis Configuration

Modify Redis settings in `terraform.tfvars`:
```hcl
# Basic Redis (no HA)
redis_tier = "BASIC"
redis_memory_size = 1

# High Availability Redis
redis_tier = "STANDARD_HA"
redis_memory_size = 4
```

### Cloud Run Settings

Modify Cloud Build configuration in `cloudbuild.yaml`:
```yaml
# Main service scaling
--min-instances=0     # Scale to zero when idle
--max-instances=10    # Maximum concurrent instances
--memory=2Gi          # Memory per instance
--cpu=2               # CPUs per instance
--concurrency=80      # Requests per instance
```

## 🔄 Updating Your Fork

Since this deployment is external to your fork, updating is seamless:

```bash
# Sync your fork with upstream
git fetch upstream
git merge upstream/main

# Redeploy application (infrastructure unchanged)
./deployment/scripts/deploy-application.sh
```

## 📊 Monitoring and Logging

### Built-in Monitoring

Cloud Run provides automatic monitoring:
- **Metrics**: Request count, latency, CPU, memory
- **Logs**: Application logs and system logs
- **Alerts**: Configure in Cloud Monitoring console

### View Logs

```bash
# View main service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=flowise-main" --limit=50

# View worker service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=flowise-worker" --limit=50
```

### Monitor Performance

```bash
# Get service status
gcloud run services describe flowise-main --region=us-central1

# Check recent deployments
gcloud run revisions list --service=flowise-main --region=us-central1
```

## 💰 Cost Optimization

### Estimated Monthly Costs (us-central1)

| Component | Configuration | Est. Cost/Month |
|-----------|---------------|-----------------|
| Cloud Run Main | 2 vCPU, 2GB, 100 req/min | ~$15-30 |
| Cloud Run Worker | 2 vCPU, 2GB, always-on | ~$35-50 |
| Cloud SQL | db-f1-micro | ~$7-15 |
| Memorystore Redis | 1GB Basic | ~$25 |
| Cloud Storage | 100GB storage | ~$2 |
| **Total** | | **~$84-122** |

### Cost Reduction Tips

1. **Scale to Zero**: Main service scales to $0 when idle
2. **Right-size Database**: Start with `db-f1-micro`, upgrade as needed
3. **Optimize Workers**: Reduce `min-instances` if processing is light
4. **Regional Resources**: Keep all resources in same region

## 🛠️ Troubleshooting

### Common Issues

**1. Build Failures**
```bash
# Check build logs
gcloud builds list --limit=5
gcloud builds log BUILD_ID
```

**2. Service Won't Start**
```bash
# Check service logs
gcloud run services logs read flowise-main --region=us-central1
```

**3. Database Connection Issues**
```bash
# Verify secrets
gcloud secrets versions access latest --secret="flowise-db-config"
```

**4. Redis Connection Issues**
```bash
# Check Redis instance
gcloud redis instances describe flowise-redis --region=us-central1
```

### Manual Deployment Commands

If scripts fail, you can run commands manually:

```bash
# Build and deploy main service
gcloud builds submit --config=deployment/cloudbuild.yaml

# Update service with secrets
gcloud run services update flowise-main \
  --region=us-central1 \
  --update-secrets=DATABASE_HOST=flowise-db-config:latest:host
```

## 🔐 Security Best Practices

- ✅ **Secrets Management**: All sensitive data in Secret Manager
- ✅ **Network Security**: Services communicate internally
- ✅ **SSL/TLS**: Automatic HTTPS termination
- ✅ **IAM**: Principle of least privilege
- ✅ **Database**: SSL-required connections
- ✅ **Monitoring**: Comprehensive logging and alerting

## 📚 Additional Resources

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud SQL PostgreSQL](https://cloud.google.com/sql/docs/postgres)
- [Memorystore Redis](https://cloud.google.com/memorystore/docs/redis)
- [Flowise Documentation](https://docs.flowiseai.com/)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## 🆘 Support

If you encounter issues:

1. **Check logs** in Cloud Console
2. **Review configuration** files
3. **Validate** terraform.tfvars settings
4. **Ensure** all required APIs are enabled
5. **Verify** authentication and permissions

For Flowise-specific issues, refer to the [upstream repository](https://github.com/FlowiseAI/Flowise).
