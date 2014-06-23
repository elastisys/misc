#!/bin/bash

#
# Prepares the autoscaling server by downloading the private (SSH login) 
# instance key to use to check liveness on scaling group instances and 
# adds it to the cloud adapter's configuration.
#
# After the script completes, one still needs to (1) fill in placeholders 
# in the awsasadapter and autoscaler configurations and (2) start the 
# awsasadapter and autoscaler services.
#

echo "*** Preparing autoscaling server ***"

# determine region instance was launched in (used by awscli below)
availability_zone_url="http://169.254.169.254/latest/meta-data/placement/availability-zone"
export AWS_REGION=$(curl -s ${availability_zone_url} | python -c "import sys; print sys.stdin.read()[0:-1]")

# assume awscli tool is already installed on image.
# awscli knows how to get AWS access key id and secret access key from the IAM 
# profile found in the instance meta data 
# http://169.254.169.254/latest/meta-data/iam/security-credentials/AutoscalerRole

# download private key for instance keypair in order to do instance liveness checks
sudo aws s3 cp --region ${AWS_REGION} s3://atc.autoscaling.keys/instancekey.pem /etc/elastisys/security/instancekey.pem
sudo chown -R elastisys:elastisys /etc/elastisys/security/
sudo -u elastisys chmod 600 /etc/elastisys/security/instancekey.pem
export INSTANCE_KEY="/etc/elastisys/security/instancekey.pem"

expand_vars='import os, sys; print os.path.expandvars(sys.stdin.read())'
# fill in some placeholders in awsasadapter config from environment variables
export SCALING_GROUP_NAME=AtcNodeServerAutoScalingGroup
sudo -E python -c "${expand_vars}" < /etc/elastisys/awsasadapter/config.json.template > /tmp/config.json
sudo -u elastisys cp /tmp/config.json /etc/elastisys/awsasadapter/config.json
sudo -u elastisys sed -i -e 's/\"command\".*/\"command\": \"curl localhost:9000\/test | grep test\",/g' /etc/elastisys/awsasadapter/config.json


# fill in some placeholders in autoscaler config from environment variables
sudo -E python -c "${expand_vars}" < /opt/elastisys/autoscaler/instances/atcscaler/config.json > /tmp/config.json
sudo -u elastisys cp /tmp/config.json /opt/elastisys/autoscaler/instances/atcscaler/config.json

echo "*********************************************************************"
echo "*** Done preparing autoscaling server                             ***"
echo "*** Remaining steps:                                              ***"
echo "*** 1. fill in placeholders in:                                   ***"
echo "***    /etc/elastisys/awsasadapter/config.json                    ***"
echo "***    /opt/elastisys/autoscaler/instances/atcscaler/config.json  ***"
echo "*** 2. start services:                                            ***"
echo "***    sudo service awsasadapter start                            ***"
echo "***    sudo service autoscaler start                              ***"
echo "*********************************************************************"
