#!/bin/bash

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

autoscaler_security_group=AtcAutoscalingServer
autoscaler_keypair=AtcAutoscalingServerKeypair
autoscaler_iam_role=AutoscalerRole
autoscaler_iam_profile=AutoscalerProfile


response=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=AutoscalingServer")
extract_id='import sys, json; print json.loads(sys.stdin.read())["Reservations"][0]["Instances"][0]["InstanceId"]'
autoscaler_instance_id=$(echo ${response} | python -c "${extract_id}")
if [ "${autoscaler_instance_id}" != "" ]; then
    echo ">>> Deleting Autoscaling Server ${autoscaler_instance_id} ..."
    aws ec2 terminate-instances --instance-ids ${autoscaler_instance_id}
    echo ">>> Waiting for Autoscaling Server to be deleted ..."
    sleep 90
fi

echo ">>> Deleting IAM autoscaler profile ..."
aws iam remove-role-from-instance-profile --instance-profile-name ${autoscaler_iam_profile} --role-name ${autoscaler_iam_role}
aws iam delete-instance-profile --instance-profile-name ${autoscaler_iam_profile}
echo ">>> Deleting IAM autoscaler role ..."
aws iam delete-role-policy --role-name ${autoscaler_iam_role} --policy-name s3keyread
aws iam delete-role --role-name ${autoscaler_iam_role}
echo ">>> Deleting keypairs ..."
aws ec2 delete-key-pair --key-name ${autoscaler_keypair}
bucket="s3://atc.autoscaling.keys"
echo ">>> Deleting private keys from S3 bucket ${bucket} ..."
aws s3 rm ${bucket}/autoscalerkey.pem
echo ">>> Deleting security groups ..."
aws ec2 delete-security-group --group-name ${autoscaler_security_group}
