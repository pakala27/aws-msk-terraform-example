Project Details:

This Github repo was created to acheive below tasks:

1. Install AWS MSK with Terraform 
2. Enable SASL- IAM authentication
3. Create IAM policy to grant permission and attach it a IAM user
4. Install and configure Prometheus server for AWS MSK monitoring
5. Create Producer to send some number of messages per second to test the cluster
6. Observe Consumer lag for the topic from a consumer group


Usage of repo:

## Terraform
git clone repo
cd repo/terraform
terraform init
terraform plan
terraform apply

## IAM Policy and user
refer IAM/policy-msk-ops.json and create policy in UI 
attach the policy to the user aws-msk-user

Desclaimer: Can be automated this step

## Setting up the devops system that will be used for prometheus and kafka producer
./devops/preflight.sh

## Setup Prometheus server
Follow prometheus/setup document for prometheus installation and configurations
Access the prometheus server from outside as it has necessary inbound rule

## Setup Kafka producer
I  plat to run kafka producer CLI on devops (EC2) instance
floow producer/setup

## Observe the consumer lag for the consumer group for a specific topic
refer producer/consumer-lag.png 



