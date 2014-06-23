#!/bin/bash

#
# Prerequisite software: http://aws.amazon.com/cli/ (sudo pip install awscli)
#

if [ "${AWS_ACCESS_KEY_ID}" = "" ]; then
    echo "error: Please make sure \${AWS_ACCESS_KEY_ID} is set."
    exit 1
fi

if [ "${AWS_SECRET_ACCESS_KEY}" = "" ]; then
    echo "error: Please make sure \${AWS_SECRET_ACCESS_KEY} is set."
    exit 1
fi

export AWS_DEFAULT_REGION=eu-west-1
region=${AWS_DEFAULT_REGION}

# name prefix for created artifacts
prefix="PoC-"

# Test client instance settings
testclient_ami="ami-bbe72acc"
testclient_name="${prefix}AtcTestClientInstance"
testclient_instancetype="m1.small"
testclient_security_group=${prefix}AtcTestClient
testclient_keypair=${prefix}AtcTestClientKeypair

# 0. prepare AWS account
echo ">>> Creating security groups ..."
# - create a test client security group with port openings: 22
aws ec2 create-security-group --group-name ${testclient_security_group} --description "ATC Node Server"
aws ec2 authorize-security-group-ingress --group-name ${testclient_security_group} --protocol tcp --port 22 --cidr 0.0.0.0/0
# - create a test client keypair
echo ">>> Creating key pairs ..."
extract_key='import sys, json; print json.loads(sys.stdin.read())["KeyMaterial"]'
aws ec2 create-key-pair --key-name ${testclient_keypair} | python -c "${extract_key}" > /tmp/AtcTestClientKey.pem
# - store away the private keys in an S3 bucket
bucket="s3://atc.autoscaling.keys"
echo ">>> Creating S3 bucket ${bucket} ..."
aws s3 mb --region ${region} ${bucket}
aws s3 cp --region ${region} /tmp/AtcTestClientKey.pem ${bucket}/testclientkey.pem

# launch test client EC2 instance
echo ">>> Creating test client from AMI ${testclient_ami} ..."
response=$(aws ec2 run-instances --instance-type ${testclient_instancetype} --image-id ${testclient_ami} --key-name ${testclient_keypair} --security-groups ${testclient_security_group})
echo ${response}
extract_id='import sys, json; print json.loads(sys.stdin.read())["Instances"][0]["InstanceId"]'
instance_id=$(echo ${response} | python -c "${extract_id}")
aws ec2 create-tags --resources ${instance_id} --tags Key=Name,Value=${testclient_name}
