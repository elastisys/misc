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

elb_name="AtcNodeServerELB"
launchconfig_name="AtcNodeServerLaunchConfig"
asgroup_name="AtcNodeServerAutoScalingGroup"

nodeserver_security_group=AtcNodeServer
nodeserver_keypair=AtcNodeServerKeypair


echo ">>> Deleting Auto Scaling Group ..."
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name ${asgroup_name} --force-delete
exit_code=$?
if [ "${exit_code}" = "0" ]; then
    echo ">>> Waiting for entire scaling group to be deleted ..."
    sleep 120
fi
echo ">>> Deleting Launch Configuration ..."
aws autoscaling delete-launch-configuration --launch-configuration-name ${launchconfig_name}
echo ">>> Deleting Elastic Load Balancer ..."
aws elb delete-load-balancer --load-balancer-name ${elb_name}
echo ">>> Deleting keypairs ..."
aws ec2 delete-key-pair --key-name ${nodeserver_keypair}
bucket="s3://atc.autoscaling.keys"
echo ">>> Deleting private keys from S3 bucket ${bucket} ..."
aws s3 rm ${bucket}/instancekey.pem
echo ">>> Deleting security groups ..."
aws ec2 delete-security-group --group-name ${nodeserver_security_group}
