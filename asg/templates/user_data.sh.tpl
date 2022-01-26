#!/bin/bash

# ------------
# log and get user-data.sh script in root directory
# ------------
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

  echo "Hello from user-data!"
  curl -s "http://169.254.169.254/latest/user-data" > "/root/user-data.sh"
  chmod 755 /root/user-data.sh


# ------------
# put tags in /etc/ec2-tags, $role in hostname is getting from here
# ------------
instance_id=$(wget -qO- http://instance-data/latest/meta-data/instance-id)
region=$(wget -qO- http://instance-data/latest/meta-data/placement/availability-zone | sed 's/.$//')
aws ec2 describe-tags --region eu-west-1 --filter "Name=resource-id,Values=$${instance_id}" --output=text | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/' | grep -v ":\|-"> "/etc/ec2-tags"
source "/etc/ec2-tags"

# ------------
# upgrade server & install mandatory
# ------------
# upgrade EC2
echo "upgrade EC2 | yum update -y | yum upgrade -y | yum install -y git | yum install -y jq"
yum update -y
yum upgrade -y
yum install -y git
yum install -y jq

# install pip
yum install -y unzip python2-pip.noarch

# get ansible package from s3 and install it
echo "get ansible package from s3 and install it"
su - ec2-user -c "aws s3 cp s3://elieof-eoo/artifacts/ansible/eoo-consul.zip /tmp"
su - ec2-user -c "unzip /tmp/eoo-consul.zip -d /home/ec2-user/"

# install ansible
echo "install ansible"
pip install --upgrade pip
pip install --upgrade python-consul
pip install --upgrade boto
pip install --upgrade boto3
pip install --upgrade botocore
pip install --upgrade awscli
pip install ansible==$(cat /home/ec2-user/.ansible.version)

# ------------
# Deployment
# ------------
su - ec2-user -c "ansible-playbook -vvv /home/ec2-user/main.yml"
