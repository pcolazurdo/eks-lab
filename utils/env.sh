AWS_REGION=us-east-2
CLUSTER_NAME=$(eksctl get cluster -o json | jq -r '.[].metadata.name')
STACK_NAME=$(eksctl get nodegroup --cluster ${CLUSTER_NAME} -o json | jq -r '.[].StackName')
ROLE_NAME=$(aws cloudformation describe-stack-resources --stack-name $STACK_NAME | jq -r '.StackResources[] | select(.ResourceType=="AWS::IAM::Role") | .PhysicalResourceId')
ROLE_NAME=${ROLE_NAME}
alias k='kubectl'
