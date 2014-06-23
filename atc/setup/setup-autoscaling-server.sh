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

if [ "${AWS_DEFAULT_REGION}" = "" ]; then
    export AWS_DEFAULT_REGION="eu-west-1"
fi

region=${AWS_DEFAULT_REGION}

# Autoscaling Server parameters
autoscaling_server_ami="ami-1fc50d68"
autoscaling_server_name="AutoscalingServer"
autoscaler_instance_type="m1.small"
autoscaler_security_group="AtcAutoscalingServer"
autoscaler_keypair="AtcAutoscalingServerKeypair"
autoscaler_iam_role="AutoscalerRole"
autoscaler_iam_profile="AutoscalerProfile"

echo ">>> Creating ${autoscaler_security_group} security group ..."
aws ec2 create-security-group --group-name ${autoscaler_security_group} --description "ATC Autoscaling Server"
aws ec2 authorize-security-group-ingress --group-name ${autoscaler_security_group} --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name ${autoscaler_security_group} --protocol tcp --port 4242 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name ${autoscaler_security_group} --protocol tcp --port 8443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name ${autoscaler_security_group} --protocol tcp --port 9443 --cidr 0.0.0.0/0
echo ">>> Creating ${autoscaler_keypair} key pair ..."
extract_key='import sys, json; print json.loads(sys.stdin.read())["KeyMaterial"]'
aws ec2 create-key-pair --key-name ${autoscaler_keypair} | python -c "${extract_key}" > /tmp/AtcAutoscalingServerKey.pem
# store away the private key in an S3 bucket
bucket="s3://atc.autoscaling.keys"
echo ">>> Storing private key in S3 bucket ${bucket} ..."
aws s3 mb --region ${region} ${bucket}
aws s3 cp --region ${region} /tmp/AtcAutoscalingServerKey.pem ${bucket}/autoscalerkey.pem
echo ">>> Creating IAM ${autoscaler_iam_profile} ..."
cat > /tmp/ec2-allow.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
aws iam create-role --role-name ${autoscaler_iam_role} --assume-role-policy-document file:///tmp/ec2-allow.json
cat > /tmp/autoscaling-keys-access-policy.json <<EOF
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [ 
        "s3:Get*",
        "s3:List*"
      ],
      "Resource": [
        "arn:aws:s3:::atc.autoscaling.keys",
        "arn:aws:s3:::atc.autoscaling.keys/*"
      ]
    }
  ]
}
EOF
aws iam put-role-policy --role-name ${autoscaler_iam_role} --policy-name s3keyread --policy-document file:///tmp/autoscaling-keys-access-policy.json
# create an 'AutoscalerProfile' instance profile as a container for the instance role
aws iam create-instance-profile --instance-profile-name ${autoscaler_iam_profile}
aws iam add-role-to-instance-profile --instance-profile-name ${autoscaler_iam_profile} --role-name ${autoscaler_iam_role}

echo ">>> Waiting for eventually consistent operations to take effect ..."
sleep 30

# launch an autoscaling server EC2 instance (with the autoscaling server AMI and AutoscalerRole IAM role)
echo ">>> Creating autoscaling server from AMI ${autoscaling_server_ami} ..."
response=$(aws ec2 run-instances --instance-type ${autoscaler_instance_type} --image-id ${autoscaling_server_ami} --key-name ${autoscaler_keypair} --security-groups ${autoscaler_security_group} --iam-instance-profile Name="${autoscaler_iam_profile}" --user-data file://autoscaling-server-boot.sh)
echo ">>> Autoscaling server: ${response}"
extract_id='import sys, json; print json.loads(sys.stdin.read())["Instances"][0]["InstanceId"]'
instance_id=$(echo ${response} | python -c "${extract_id}")
aws ec2 create-tags --resources ${instance_id} --tags Key=Name,Value=${autoscaling_server_name}

