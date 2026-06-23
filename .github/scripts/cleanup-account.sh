
echo "⚠️  WARNING: This will delete ALL resources in your AWS account!"
echo "⚠️  This action is IRREVERSIBLE!"
read -p "Type 'DELETE-EVERYTHING' to confirm: " confirmation

if [ "$confirmation" != "DELETE-EVERYTHING" ]; then
    echo "Operation cancelled."
    exit 1
fi

echo "🔥 Starting account cleanup..."

# Get all regions
regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

for region in $regions; do
    echo "🔥 Cleaning region: $region"

    # 1. Terminate EC2 instances
    echo "  - Terminating EC2 instances..."
    instances=$(aws ec2 describe-instances --region $region --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' --output text)
    if [ ! -z "$instances" ]; then
        aws ec2 terminate-instances --instance-ids $instances --region $region
        echo "    Terminated instances: $instances"
    fi

    # 2. Delete EKS clusters
    echo "  - Deleting EKS clusters..."
    clusters=$(aws eks list-clusters --region $region --query 'clusters' --output text)
    for cluster in $clusters; do
        if [ ! -z "$cluster" ]; then
            aws eks delete-cluster --name $cluster --region $region
            echo "    Deleted EKS cluster: $cluster"
        fi
    done

    # 3. Delete RDS instances
    echo "  - Deleting RDS instances..."
    aws rds describe-db-instances --region $region --query 'DBInstances[].DBInstanceIdentifier' --output text | while read db; do
        if [ ! -z "$db" ]; then
            aws rds delete-db-instance --db-instance-identifier $db --skip-final-snapshot --region $region
            echo "    Deleted RDS instance: $db"
        fi
    done

    # 4. Delete RDS clusters
    echo "  - Deleting RDS clusters..."
    aws rds describe-db-clusters --region $region --query 'DBClusters[].DBClusterIdentifier' --output text | while read cluster; do
        if [ ! -z "$cluster" ]; then
            aws rds delete-db-cluster --db-cluster-identifier $cluster --skip-final-snapshot --region $region
            echo "    Deleted RDS cluster: $cluster"
        fi
    done

    # 5. Delete Load Balancers
    echo "  - Deleting Load Balancers..."
    aws elbv2 describe-load-balancers --region $region --query 'LoadBalancers[].LoadBalancerArn' --output text | while read lb; do
        if [ ! -z "$lb" ]; then
            aws elbv2 delete-load-balancer --load-balancer-arn $lb --region $region
            echo "    Deleted Load Balancer: $lb"
        fi
    done

    # 6. Delete NAT Gateways
    echo "  - Deleting NAT Gateways..."
    aws ec2 describe-nat-gateways --region $region --query 'NatGateways[?State==`available`].NatGatewayId' --output text | while read nat; do
        if [ ! -z "$nat" ]; then
            aws ec2 delete-nat-gateway --nat-gateway-id $nat --region $region
            echo "    Deleted NAT Gateway: $nat"
        fi
    done

    # 7. Delete VPC Endpoints
    echo "  - Deleting VPC Endpoints..."
    aws ec2 describe-vpc-endpoints --region $region --query 'VpcEndpoints[].VpcEndpointId' --output text | while read endpoint; do
        if [ ! -z "$endpoint" ]; then
            aws ec2 delete-vpc-endpoint --vpc-endpoint-id $endpoint --region $region
            echo "    Deleted VPC Endpoint: $endpoint"
        fi
    done
done

echo "⏳ Waiting 2 minutes for resources to terminate before cleaning up volumes..."
sleep 120

# Clean up remaining resources after termination
for region in $regions; do
    echo "🔥 Final cleanup for region: $region"

    # 8. Delete EBS volumes (after instances are terminated)
    echo "  - Deleting available EBS volumes..."
    aws ec2 describe-volumes --region $region --query 'Volumes[?State==`available`].VolumeId' --output text | while read vol; do
        if [ ! -z "$vol" ]; then
            aws ec2 delete-volume --volume-id $vol --region $region
            echo "    Deleted EBS volume: $vol"
        fi
    done
done

# 9. Delete S3 buckets (global)
echo "🔥 Deleting S3 buckets..."
aws s3api list-buckets --query 'Buckets[].Name' --output text | while read bucket; do
    if [ ! -z "$bucket" ]; then
        echo "  - Emptying bucket: $bucket"
        aws s3 rm s3://$bucket --recursive
        echo "  - Deleting bucket: $bucket"
        aws s3api delete-bucket --bucket $bucket
    fi
done

# 10. Delete Secrets Manager secrets
echo "🔥 Deleting Secrets Manager secrets..."
for region in $regions; do
    aws secretsmanager list-secrets --region $region --query 'SecretList[].Name' --output text | while read secret; do
        if [ ! -z "$secret" ]; then
            aws secretsmanager delete-secret --secret-id "$secret" --force-delete-without-recovery --region $region
            echo "    Deleted secret: $secret"
        fi
    done
done

echo "🔥 Account cleanup completed!"
echo "⚠️  Some resources may take additional time to fully delete."
echo "💰 Check your billing dashboard in a few hours to confirm cost reduction."

