# Deploying Medusa Backend to AWS ECS (Fargate) with Terraform & GitHub Actions

This project demonstrates deploying the Medusa headless commerce platform to AWS ECS using:

- **Terraform** for infrastructure provisioning
- **GitHub Actions** for CI/CD pipeline
- **Amazon ECS (Fargate)** and **ECR** for Docker image storage
- **PostgreSQL (RDS)** and **Redis (ElastiCache)** in private subnets
- **Application Load Balancer** and **Route 53** for HTTPS access

---

## Tech Stack

- **MedusaJS** – Headless Commerce Platform  
- **AWS ECS (Fargate)** – Containers 
- **AWS ECR** – Docker Image Registry  
- **Terraform** – Infrastructure as Code  
- **GitHub Actions** – CI/CD Workflow  
- **ALB + Route53 + HTTPS (ACM)** – Public access via custom domain 
- **PostgreSQL (RDS) & Redis (ElastiCache)** – Backend databases
- **SSM Parameter Store** - To store Secrets

---

## Architecture Overview

- Medusa Server and Medusa Workder runs in a **private subnet** on ECS Fargate.
- An **Application Load Balancer (ALB)** in the public subnet handles external traffic.
- ALB forwards traffic (port `443`) to Medusa on port `9000`.
- **RDS Postgres** and **ElastiCache Redis** are hosted in private subnets.
- **Route 53** points `medusa.domain.lmno` to the ALB.
- HTTPS is handled via **ACM certificate**.

---

## Terraform Infrastructure

The following resources are provisioned:

### Network

- VPC with CIDR block `10.0.0.0/24`
- 2 Public Subnets (with Internet Gateway)
- 2 Private Subnets (with NAT Gateway)
- Route tables and associations

### Security

- Security Groups for public (ALB) and private (ECS, RDS, Redis) with least access policy.
- Rules for HTTPS (443), HTTP (80), Redis (6379), Postgres (5432)

### Compute

- ECS Cluster with Fargate launch type
- ALB with HTTPS listener (redirects HTTP to HTTPS)
- Target Group forwarding to Medusa ECS service on port 9000

### Storage and Logs

- S3 bucket for ALB access logs
- CloudWatch logs for ECS Tasks

---

## GitHub Actions Workflow

- Runs on push to `main` branch.
- Checkout Code
- Login to Amazon ECR
- Build and Push Docker Image
- Trigger ECS Rolling Deployment

## Deployment Flow

- Code is pushed to main

- GitHub Action builds and pushes Docker image to ECR

- ECS service is updated with a new image

- ALB routes HTTPS traffic to ECS task on port 9000

---

## Docker 

- The Medusa backend is containerized using `Dockerfile`. It installs dependencies, builds the app, and runs it on port 9000.

## Local Development (Optional)

A `docker-compose.yml` file is available for quick local deployment. It provisions:

- Medusa backend
- PostgreSQL
- Redis

Once running, you can access the Medusa backend using your local browser at: `localhost:9000/app`

