#!/usr/bin/env bash
set -euo pipefail

VPC_ID="${1:-}"

if [[ -z "$VPC_ID" ]]; then
  echo "❌ ERROR: Missing VPC ID"
  echo "Usage: ./super-import.sh vpc-123abc"
  exit 1
fi

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
TFVARS_FILE="vpc2-us-east-1.tfvars"
TFVARS="-var-file=${TFVARS_FILE}"

echo "============================================"
echo "🚀 SUPER IMPORT for VPC: $VPC_ID (region: $REGION)"
echo "============================================"

# ---------------------------------------------
# PHASE 1: DISCOVER + GENERATE TFVARS
# ---------------------------------------------
echo "🔍 Discovering VPC CIDR..."
VPC_CIDR=$(aws ec2 describe-vpcs \
  --vpc-ids "$VPC_ID" \
  --region "$REGION" \
  --query "Vpcs[0].CidrBlock" \
  --output text)

echo "➡ VPC CIDR: $VPC_CIDR"

echo "🔍 Discovering subnets..."

SUBNETS_JSON=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region "$REGION")

PUBLIC_SUBNETS=()
PRIVATE_SUBNETS=()
PUB_CIDRS=()
PRI_CIDRS=()
AZS=()

echo "$SUBNETS_JSON" | jq -c '.Subnets[]' | while read -r row; do
    SUBNET_ID=$(echo "$row" | jq -r '.SubnetId')
    CIDR=$(echo "$row" | jq -r '.CidrBlock')
    MAP_PUBLIC=$(echo "$row" | jq -r '.MapPublicIpOnLaunch')
    AZ=$(echo "$row" | jq -r '.AvailabilityZone')

    AZS+=("$AZ")

    if [[ "$MAP_PUBLIC" == "true" ]]; then
        PUBLIC_SUBNETS+=("$SUBNET_ID")
        PUB_CIDRS+=("$CIDR")
    else
        PRIVATE_SUBNETS+=("$SUBNET_ID")
        PRI_CIDRS+=("$CIDR")
    fi
done

AZS=($(printf "%s\n" "${AZS[@]}" | sort -u))

echo "➡ Public Subnets: ${PUBLIC_SUBNETS[*]}"
echo "➡ Private Subnets: ${PRIVATE_SUBNETS[*]}"
echo "➡ AZs: ${AZS[*]}"

echo "📝 Generating ${TFVARS_FILE}..."

{
  echo "environment = \"prod\""
  echo "region      = \"${REGION}\""
  echo ""
  echo "vpc_cidr = \"${VPC_CIDR}\""
  echo ""
  echo "public_subnet_cidrs = ["
  for c in "${PUB_CIDRS[@]}"; do echo "  \"$c\","; done
  echo "]"
  echo ""
  echo "private_subnet_cidrs = ["
  for c in "${PRI_CIDRS[@]}"; do echo "  \"$c\","; done
  echo "]"
  echo ""
  echo "azs = ["
  for a in "${AZS[@]}"; do echo "  \"$a\","; done
  echo "]"
} > "$TFVARS_FILE"

echo "✅ Generated ${TFVARS_FILE}"
cat "$TFVARS_FILE"

# ---------------------------------------------
# PHASE 2: Terraform init + pre-import plan
# ---------------------------------------------
echo "🧩 terraform init..."
terraform init -input=false

echo "🧪 terraform plan (pre-import)..."
terraform plan $TFVARS || echo "⚠ Pre-import changes expected."

# ---------------------------------------------
# PHASE 3: IMPORT RESOURCES
# ---------------------------------------------
echo "============================================"
echo "📥 IMPORTING RESOURCES"
echo "============================================"

# ---- VPC ----
terraform import $TFVARS module.vpc.aws_vpc.this "$VPC_ID"

# ---- Public Subnets ----
echo "➡ Importing Public Subnets..."
idx=0
for subnet in "${PUBLIC_SUBNETS[@]}"; do
  terraform import $TFVARS "module.public_subnets.aws_subnet.this[\"$idx\"]" "$subnet"
  idx=$((idx+1))
done

# ---- Private Subnets ----
echo "➡ Importing Private Subnets..."
idx=0
for subnet in "${PRIVATE_SUBNETS[@]}"; do
  terraform import $TFVARS "module.private_subnets.aws_subnet.this[\"$idx\"]" "$subnet"
  idx=$((idx+1))
done

# ---- Internet Gateway ----
echo "🔍 Discovering Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --region "$REGION" \
  --query "InternetGateways[0].InternetGatewayId" \
  --output text)

if [[ "$IGW_ID" != "None" ]]; then
  terraform import $TFVARS module.gateways.aws_internet_gateway.igw[0] "$IGW_ID"
fi

# ---------------------------------------------
# NAT GATEWAYS (UPDATED WITH ID ECHO)
# ---------------------------------------------
echo "🔍 Discovering NAT Gateways..."
NAT_JSON=$(aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --region "$REGION")

NAT_IDS=($(echo "$NAT_JSON" | jq -r '.NatGateways[].NatGatewayId'))
EIP_ALLOC_IDS=($(echo "$NAT_JSON" | jq -r '.NatGateways[].NatGatewayAddresses[].AllocationId'))

echo "➡ Importing NAT EIPs..."
idx=0
for alloc in "${EIP_ALLOC_IDS[@]}"; do
  terraform import $TFVARS "module.gateways.aws_eip.nat[$idx]" "$alloc"
  idx=$((idx+1))
done

echo "➡ Importing NAT Gateways..."
idx=0
for nat in "${NAT_IDS[@]}"; do
  terraform import $TFVARS "module.gateways.aws_nat_gateway.nat_gw[$idx]" "$nat"
  idx=$((idx+1))
done

# ---------- NAT SUMMARY OUTPUT ----------
echo ""
echo "============================================"
echo "📌 NAT Import Summary"
echo "============================================"

echo "Imported NAT Gateways:"
for nat in "${NAT_IDS[@]}"; do
  echo " - NAT Gateway ID: $nat"
done

echo ""
echo "Imported NAT EIP Allocation IDs:"
for alloc in "${EIP_ALLOC_IDS[@]}"; do
  echo " - EIP Allocation ID: $alloc"
done

echo "============================================"

# ---------------------------------------------
# Route Tables + Associations
# ---------------------------------------------
echo "🔍 Discovering Route Tables & Associations..."

RTB_JSON=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region "$REGION")

declare -A RTB_BY_SUBNET
declare -A ASSOC_BY_SUBNET

echo "$RTB_JSON" | jq -c '.RouteTables[]' | while read -r rtb; do
    RTB_ID=$(echo "$rtb" | jq -r '.RouteTableId')

    echo "$rtb" | jq -c '.Associations[]?' | while read -r assoc; do
        SUBNET_ID=$(echo "$assoc" | jq -r '.SubnetId')
        ASSOC_ID=$(echo "$assoc" | jq -r '.RouteTableAssociationId')

        if [[ "$SUBNET_ID" != "null" ]]; then
            RTB_BY_SUBNET["$SUBNET_ID"]="$RTB_ID"
            ASSOC_BY_SUBNET["$SUBNET_ID"]="$ASSOC_ID"
        fi
    done
done

PUBLIC_RTB=()
PRIVATE_RTB=()
PUBLIC_ASSOC=()
PRIVATE_ASSOC=()

for subnet in "${PUBLIC_SUBNETS[@]}"; do
  PUBLIC_RTB+=("${RTB_BY_SUBNET[$subnet]:-}")
  PUBLIC_ASSOC+=("${ASSOC_BY_SUBNET[$subnet]:-}")
done

for subnet in "${PRIVATE_SUBNETS[@]}"; do
  PRIVATE_RTB+=("${RTB_BY_SUBNET[$subnet]:-}")
  PRIVATE_ASSOC+=("${ASSOC_BY_SUBNET[$subnet]:-}")
done

echo "➡ Importing Public Route Tables..."
idx=0
for rtb in "${PUBLIC_RTB[@]}"; do
  terraform import $TFVARS "module.route_tables.aws_route_table.public[$idx]" "$rtb"
  idx=$((idx+1))
done

echo "➡ Importing Private Route Tables..."
idx=0
for rtb in "${PRIVATE_RTB[@]}"; do
  terraform import $TFVARS "module.route_tables.aws_route_table.private[$idx]" "$rtb"
  idx=$((idx+1))
done

echo "➡ Importing Public Route Table Associations..."
idx=0
for assoc in "${PUBLIC_ASSOC[@]}"; do
  terraform import $TFVARS "module.route_tables.aws_route_table_association.public_assoc[$idx]" "$assoc"
  idx=$((idx+1))
done

echo "➡ Importing Private Route Table Associations..."
idx=0
for assoc in "${PRIVATE_ASSOC[@]}"; do
  terraform import $TFVARS "module.route_tables.aws_route_table_association.private_assoc[$idx]" "$assoc"
  idx=$((idx+1))
done

# ---------------------------------------------
# FINAL PLAN
# ---------------------------------------------
echo "============================================"
echo "🎉 IMPORT COMPLETE — Running final plan..."
echo "============================================"

terraform plan $TFVARS
