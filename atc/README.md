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

    ./setup/setup-autoscaling-group.sh
    ./setup/setup-autoscaling-server.sh


To also launch a test client instance, with the TestClient AMI, run:

    ./testclient/testclient-setup.sh

*Note: a test client session needs to be manually started on the test
client to apply load.*

Tear down
=========
To take everything down you need to run:

    ./setup/teardown-autoscaling-server.sh
    ./setup/teardown-autoscaling-group.sh


In case a test client instance was started, also run:

    ./testclient/testclient-setup.sh

