Import-friendly Terraform VPC stack with multi-env (dev/prod).

Structure:
- modules/
  - vpc
  - subnets
  - gateways
  - route-tables
- envs/dev
- envs/prod (with import.sh)

Dev usage:
  cd envs/dev
  terraform init
  terraform apply -var-file=dev.tfvars

Prod import usage (import existing VPC):
  cd envs/prod
  terraform init
  terraform plan -var-file=prod.tfvars   # optional but recommended
  ./import.sh vpc-xxxxxxxxxxxxxxxxx
  terraform plan -var-file=prod.tfvars

