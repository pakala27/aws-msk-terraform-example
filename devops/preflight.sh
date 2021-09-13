#!/bin/bash
set -e

echo "Install Java 11"
sudo yum install -y java-11-openjdk-devel

echo "Install wget and unzip"
sudo yum install -y wget unzip

echo "Download Kafka"
wget https://downloads.apache.org/kafka/2.8.0/kafka_2.13-2.8.0.tgz
tar -xf kafka_2.13-2.8.0.tgz
export PATH=$PATH:/home/ec2-user/kafka_2.13-2.8.0/bin
echo 'export PATH=$PATH:/home/ec2-user/kafka_2.13-2.8.0/bin' >> /home/ec2-user/.bashrc

echo "Install AWS Cli"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

echo "Download AWS MSK library for AWS IAM"
wget https://github.com/aws/aws-msk-iam-auth/releases/download/v1.1.1/aws-msk-iam-auth-1.1.1-all.jar
export CLASSPATH=/home/ec2-user/aws-msk-iam-auth-1.1.1-all.jar
echo 'export CLASSPATH=/home/ec2-user/aws-msk-iam-auth-1.1.1-all.jar' >> /home/ec2-user/.bashrc