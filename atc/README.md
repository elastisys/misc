Prerequisites
=============
Before running any of the setup scripts, make sure you have installed
[AWS Command-line interface](http://aws.amazon.com/cli/):
 
    sudo pip install awscli

Also, set your AWS credentials and the AWS region you want to run
the scripts against.

    export AWS_ACCESS_KEY_ID=...
    export AWS_SECRET_ACCESS_KEY=...    
    export AWS_DEFAULT_REGION="eu-west-1"


Set up
======
To set up an autoscaling group and an autoscaling server, run:

    cd setup
    ./setup-autoscaling-group.sh
    ./setup-autoscaling-server.sh


To also launch a test client instance, with the TestClient AMI, run:

    cd testclient
    ./testclient-setup.sh

*Note: a test client session needs to be manually started on the test
client to apply load.*



Each instance is started with a separate key pair. To log into the instances
(via ssh), retrieve the private keys via (using AWS credentials with sufficient
access privileges):

    # autoscaler
    aws s3 --region eu-west-1 cp s3://atc.autoscaling.keys/autoscalerkey.pem .
    # node server instances
    aws s3 --region eu-west-1 cp s3://atc.autoscaling.keys/instancekey.pem .
    # test client
    aws s3 --region eu-west-1 cp s3://atc.autoscaling.keys/testclientkey.pem .
    chmod 600 *.pem


Tear down
=========
To take everything down you need to run:

    ./setup/teardown-autoscaling-server.sh
    ./setup/teardown-autoscaling-group.sh


In case a test client instance was started, also run:

    ./testclient/testclient-teardown.sh

