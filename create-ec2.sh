#!/bin/bash

instances=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "web")
domain_name="sivakumar.cloud"
hosted_zone_id="Z092676436YRLO4PFIUP4"

#!/bin/bash

instances=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "web")
domain_name="sivakumar.cloud"
hosted_zone_id="Z092676436YRLO4PFIUP4"

for name in ${instances[@]}; do
    if [ $name == "shipping" ] || [ $name == "mysql" ]
    then
        instance_type="t3.medium"
    else
        instance_type="t3.micro"
    fi
    echo "Creating instance for: $name with instance type: $instance_type"
    instance_id=$(aws ec2 run-instances --image-id ami-09c813fb71547fc4f --instance-type $instance_type --security-group-ids subnet-0a6c830ec2e8dfe11 --subnet-id subnet-02fefb5d9b3631b6f --query 'Instances[0].InstanceId' --output text)
    
    if [ -z "$instance_id" ]; then
        echo "Instance creation failed for: $name"
        continue
    fi

    echo "Instance created for: $name with ID $instance_id"
    aws ec2 create-tags --resources $instance_id --tags Key=Name,Value=$name

    if [ $name == "web" ]; then
        aws ec2 wait instance-running --instance-ids $instance_id
        public_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].[PublicIpAddress]' --output text)
        ip_to_use=$public_ip
    else
        private_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].[PrivateIpAddress]' --output text)
        ip_to_use=$private_ip
    fi

    echo "Creating R53 record for $name"
    aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch "
    {
        \"Comment\": \"Creating a record set for $name\",
        \"Changes\": [{
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"$name.$domain_name\",
                \"Type\": \"A\",
                \"TTL\": 1,
                \"ResourceRecords\": [{
                    \"Value\": \"$ip_to_use\"
                }]
            }
        }]
    }"
done
