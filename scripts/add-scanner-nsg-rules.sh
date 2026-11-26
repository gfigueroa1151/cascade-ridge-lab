#!/bin/bash
# Phase 6: let the Nessus scanner (vm-scan01, 10.0.2.4) reach the scan targets.
# Each rule allows ONLY the scanner's IP, ONLY on the ports a credentialed scan needs.
# Run in Azure Cloud Shell (Bash).

SCANNER="10.0.2.4"

add_rule() {
  local NSG=$1 DEST=$2 PORTS=$3 PRIORITY=$4
  local RG
  RG=$(az network nsg list --query "[?name=='$NSG'].resourceGroup | [0]" -o tsv)
  if [ -z "$RG" ]; then echo "Could not find $NSG, skipping"; return; fi

  echo "Adding rule to $NSG (resource group $RG)..."
  az network nsg rule create \
    --resource-group "$RG" --nsg-name "$NSG" \
    --name "Allow-Scan-From-Scanner" \
    --priority "$PRIORITY" --direction Inbound --access Allow --protocol Tcp \
    --source-address-prefixes "$SCANNER" --source-port-ranges '*' \
    --destination-address-prefixes "$DEST" \
    --destination-port-ranges $PORTS \
    --description "Nessus credentialed scan from vm-scan01" \
    --output table
}

#        NSG           Destination  Ports                    Priority
add_rule nsg-identity  10.2.1.4     "135 445 49152-65535"    230
add_rule nsg-finance   10.1.1.4     "135 445 49152-65535"    120
add_rule nsg-sales     10.1.2.4     "135 445 49152-65535"    120
add_rule nsg-apps      10.2.2.4     "22 443"                 120

echo "Done. Rules now in place:"
for NSG in nsg-identity nsg-finance nsg-sales nsg-apps; do
  RG=$(az network nsg list --query "[?name=='$NSG'].resourceGroup | [0]" -o tsv)
  az network nsg rule show -g "$RG" --nsg-name "$NSG" -n Allow-Scan-From-Scanner \
    --query "{NSG:'$NSG', Priority:priority, Source:sourceAddressPrefix, Dest:destinationAddressPrefix, Ports:join(', ', destinationPortRanges)}" -o table
done
