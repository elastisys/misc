#!/bin/bash

if [ "${AWS_ACCESS_KEY_ID}" = "" ]; then
    echo "error: Please make sure \${AWS_ACCESS_KEY_ID} is set."
    exit 1
fi

if [ "${AWS_SECRET_ACCESS_KEY}" = "" ]; then
    echo "error: Please make sure \${AWS_SECRET_ACCESS_KEY} is set."
    exit 1
fi

export AWS_DEFAULT_REGION=eu-west-1

# name prefix for created artifacts
prefix="PoC-"

# Test client instance settings
testclient_name="${prefix}AtcTestClientInstance"
testclient_security_group=${prefix}AtcTestClient
testclient_keypair=${prefix}AtcTestClientKeypair


response=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${testclient_name}")
extract_id='import sys, json; print json.loads(sys.stdin.read())["Reservations"][0]["Instances"][0]["InstanceId"]'
testclient_instance_id=$(echo ${response} | python -c "${extract_id}")
if [ "${testclient_instance_id}" != "" ]; then
    echo ">>> Deleting TestClient ${testclient_instance_id} ..."
    aws ec2 terminate-instances --instance-ids ${testclient_instance_id}
    echo ">>> Waiting for TestClient to be deleted ..."
    sleep 90
fi

echo ">>> Deleting keypair ..."
aws ec2 delete-key-pair --key-name ${testclient_keypair}
bucket="s3://atc.autoscaling.keys"
echo ">>> Deleting private key from S3 bucket ${bucket} ..."
aws s3 rm ${bucket}/testclientkey.pem
echo ">>> Deleting security group ..."
aws ec2 delete-security-group --group-name ${testclient_security_group}
