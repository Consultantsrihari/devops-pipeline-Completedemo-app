# devops-pipeline-Completedemo-app
Complete DevOps Pipeline on AWS: GitHub, Jenkins, Prometheus, Grafana, Docker, K8s, Terraform

# This project focuses on automating the entire software delivery lifecycle:
* Source Code Management (SCM): GitHub
* Continuous Integration (CI): Building, testing code using Jenkins.
*  Continuous Delivery/Deployment (CD): Deploying containerized applications to AWS Elastic Container Service (ECS).
* Monitoring & Alerting: Collecting metrics with Prometheus and visualizing with Grafana.
* Infrastructure as Code (IaC): Managing AWS resources with Terraform.

# Key AWS Services Used:
VPC (Virtual Private Cloud): Isolated network environment.
EC2 (Elastic Compute Cloud): Virtual machines for Jenkins, Prometheus, Grafana.
ECS (Elastic Container Service): Container orchestration for the application.
ECR (Elastic Container Registry): Docker image repository.
ALB (Application Load Balancer): Distributes incoming application traffic.
IAM (Identity and Access Management): Manages permissions for AWS resources.
S3 (Simple Storage Service): For Terraform state.
2. Tools Overview
GitHub: Your source code repository. Triggers Jenkins builds via webhooks.
Jenkins: The heart of your CI/CD pipeline. Orchestrates build, test, and deployment stages.
Docker: Used to containerize your application, ensuring consistent environments.
Terraform: Infrastructure as Code (IaC) tool to provision and manage your AWS resources.
Prometheus: A powerful open-source monitoring system. It collects metrics from your applications and infrastructure.
Grafana: The leading open-source platform for analytics and monitoring. It allows you to query, visualize, alert on, and understand your metrics from Prometheus.
3. Pre-requisites
Before you start, ensure you have:
AWS Account: With administrative access.
AWS CLI: Configured with your credentials. aws configure.
Terraform: Installed on your local machine.
Git: Installed on your local machine.
GitHub Account: To host your application code.
Basic understanding of Linux commands.
Basic understanding of Docker.
