#! /bin/bash

cd /tmp
yum install -y unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install


/usr/local/bin/aws s3 cp s3://is-chenjie-bucket-01/interview/bootstrap.sh /tmp/bootstrap.sh

chmod +x /tmp/bootstrap.sh

/tmp/bootstrap.sh

