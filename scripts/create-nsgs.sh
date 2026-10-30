#!/usr/bin/env bash
# Phase 2: creates the remaining 8 NSGs, adds Deny-VNet-Inbound at priority 4000,
# and attaches each NSG to its subnet. Run in Azure Cloud Shell (Bash).
# If you paste this from Windows, save it to a file and run: sed -i 's/\r$//' create-nsgs.sh

RG="rg-core"
LOC="westus"
LIST="nsg-staff|vnet-corp|snet-staff nsg-apps|vnet-servers|snet-apps nsg-pe|vnet-servers|snet-pe nsg-ai|vnet-sandbox|snet-ai nsg-attack|vnet-sandbox|snet-attack nsg-honeypot|vnet-sandbox|snet-honeypot nsg-mgmt|vnet-hub|snet-mgmt nsg-fw-outside|vnet-hub|snet-fw-outside"

for LINE in $LIST; do
  NSG=$(echo "$LINE" | cut -d'|' -f1)
  VNET=$(echo "$LINE" | cut -d'|' -f2)
  SUBNET=$(echo "$LINE" | cut -d'|' -f3)
  echo "== $NSG -> $VNET/$SUBNET"
  az network nsg create -g "$RG" -n "$NSG" -l "$LOC" --tags project=cascade-ridge owner=carlos phase=2 -o none
  az network nsg rule create -g "$RG" --nsg-name "$NSG" -n Deny-VNet-Inbound --priority 4000 \
    --direction Inbound --access Deny --protocol '*' \
    --source-address-prefixes VirtualNetwork --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges '*' -o none
  az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET" --network-security-group "$NSG" -o none
done
