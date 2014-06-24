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
availability_zones="${region}a ${region}b ${region}c"

# ELB settings
elb_name="AtcNodeServerELB"

# Launch Configuration settings
launchconfig_name="AtcNodeServerLaunchConfig"

# Auto Scaling Group instance settings (Node server)
nodeserver_port=8810
nodeserver_test_port=9000
nodeserver_protocol="tcp"
nodeserver_ami="ami-d9d618ae"
nodeserver_instancetype="m1.small"
nodeserver_security_group=AtcNodeServer
nodeserver_keypair=AtcNodeServerKeypair
# set to file://.. in case user data is needed
nodeserver_userdata=""

# Auto Scaling Group
asgroup_name="AtcNodeServerAutoScalingGroup"
min_pool_size=0
max_pool_size=4
init_pool_size=1
instance_name=AtcNodeServerInstance

echo ">>> Creating ${nodeserver_security_group} security group ..."
# - create a Node Server security group with port openings: 22, 8810
aws ec2 create-security-group --group-name ${nodeserver_security_group} --description "ATC Node Server"
aws ec2 authorize-security-group-ingress --group-name ${nodeserver_security_group} --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name ${nodeserver_security_group} --protocol tcp --port ${nodeserver_port} --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name ${nodeserver_security_group} --protocol tcp --port ${nodeserver_test_port} --cidr 0.0.0.0/0
echo ">>> Creating ${nodeserver_keypair} key pair ..."
extract_key='import sys, json; print json.loads(sys.stdin.read())["KeyMaterial"]'
aws ec2 create-key-pair --key-name ${nodeserver_keypair} | python -c "${extract_key}" > /tmp/AtcNodeServerKey.pem
# - store away the private keys in an S3 bucket
bucket="s3://atc.autoscaling.keys"
echo ">>> Storing private key in S3 bucket ${bucket} ..."
aws s3 mb --region ${region} ${bucket}
aws s3 cp --region ${region} /tmp/AtcNodeServerKey.pem ${bucket}/instancekey.pem


# 1. set up an Elastic Load Balancer
echo ">>> Creating an Elastic Load Balancer ..."
aws elb create-load-balancer --load-balancer-name ${elb_name} --listeners Protocol=${nodeserver_protocol},LoadBalancerPort=${nodeserver_port},InstanceProtocol=${nodeserver_protocol},InstancePort=${nodeserver_port} Protocol=${nodeserver_protocol},LoadBalancerPort=${nodeserver_test_port},InstanceProtocol=${nodeserver_protocol},InstancePort=${nodeserver_test_port} --availability-zones ${availability_zones}
aws elb describe-load-balancers
# Enable cross-zone load balancing (have each elb node route traffic to the 
# back-end instances across all Availability Zones). 
aws elb modify-load-balancer-attributes --load-balancer-name ${elb_name} --load-balancer-attributes '{"CrossZoneLoadBalancing": {"Enabled": true}}'
# configure the ELB instance health checks
aws elb configure-health-check --load-balancer-name ${elb_name} --health-check Target=TCP:${nodeserver_port},Interval=20,Timeout=5,UnhealthyThreshold=2,HealthyThreshold=2

# 2. set up a Launch Configuration
echo ">>> Creating a Launch Configuration ..."
userdata_opt=""
if [ "${nodeserver_userdata}" != "" ]; then
    userdata_opt="--user-data ${nodeserver_userdata}"
fi
aws autoscaling create-launch-configuration --launch-configuration-name ${launchconfig_name} --image-id ${nodeserver_ami} --instance-type ${nodeserver_instancetype} --security-groups ${nodeserver_security_group} --key-name ${nodeserver_keypair} ${userdata_opt}
aws autoscaling describe-launch-configurations

# 3. set up an Auto Scaling Group
echo ">>> Creating an Auto Scaling Group ..."
aws autoscaling create-auto-scaling-group --auto-scaling-group-name ${asgroup_name} --launch-configuration-name ${launchconfig_name} --min-size ${min_pool_size} --max-size ${max_pool_size} --desired-capacity ${init_pool_size} --default-cooldown 0 --load-balancer-names ${elb_name} --termination-policies OldestInstance --availability-zones ${availability_zones} --tags ResourceId=${asgroup_name},ResourceType=auto-scaling-group,Key=Name,Value=${instance_name},PropagateAtLaunch=true
aws autoscaling describe-auto-scaling-groups
