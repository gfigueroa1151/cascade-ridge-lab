# Network Reference

The current state of the network. I update this as the lab grows.

[Back to README](../README.md)

## Address plan

| VNet | Subnet | CIDR | Purpose | Route table |
|---|---|---|---|---|
| vnet-hub 10.0.0.0/16 | snet-fw-outside | 10.0.0.0/24 | Firewall WAN side | none |
| | snet-fw-inside | 10.0.1.0/24 | Firewall LAN side | none |
| | snet-mgmt | 10.0.2.0/24 | Nessus scanner, admin tools | rt-mgmt |
| vnet-corp 10.1.0.0/16 | snet-finance | 10.1.1.0/24 | Finance workstation | rt-spokes |
| | snet-sales | 10.1.2.0/24 | Sales workstation (remote user) | rt-spokes |
| | snet-staff | 10.1.3.0/24 | HR, Ops, Exec | rt-spokes |
| vnet-servers 10.2.0.0/16 | snet-identity | 10.2.1.0/24 | Domain controller and DNS | rt-spokes |
| | snet-apps | 10.2.2.0/24 | CRM web app | rt-spokes |
| | snet-pe | 10.2.3.0/24 | Private endpoints | rt-spokes |
| vnet-sandbox 10.3.0.0/16 | snet-ai | 10.3.1.0/24 | AI agent | rt-spokes |
| | snet-attack | 10.3.2.0/24 | Kali attack box | rt-spokes |
| | snet-honeypot | 10.3.3.0/24 | Internet-facing honeypot | none (on purpose) |
| outside Azure | VPN clients | 10.100.0.0/24 | WireGuard | n/a |

## Firewall (vm-fw01)

| Item | Value |
|---|---|
| WAN | 10.0.0.4, default gateway 10.0.0.1 |
| LAN | 10.0.1.4, gateway LAN_AZURE_GW 10.0.1.1 |
| Static routes via LAN | 10.1.0.0/16, 10.2.0.0/16, 10.3.0.0/16, 10.0.2.0/24 |
| Outbound NAT | Hybrid, WAN rule for 10.0.0.0/8 |
| VPN | WireGuard, UDP 51820, tunnel 10.100.0.0/24, split tunnel |

## Route tables

| Table | Route | Next hop |
|---|---|---|
| rt-spokes | 0.0.0.0/0 | 10.0.1.4 |
| rt-spokes | 10.0.2.0/24 | 10.0.1.4 |
| rt-mgmt | 10.1.0.0/16, 10.2.0.0/16, 10.3.0.0/16 | 10.0.1.4 |
| rt-mgmt | 0.0.0.0/0 | 10.0.1.4 |

## Key NSG rules

| NSG | Rule |
|---|---|
| Every NSG except nsg-fw-inside | Deny-VNet-Inbound at 4000 |
| nsg-fw-outside | Allow UDP 51820 (WireGuard) to 10.0.0.4 |
| nsg-fw-inside | Inbound: allow 10.0.0.0/8 to any. Outbound: allow 10.100.0.0/24 to 10.0.0.0/8 |
| nsg-attack | Allow SSH from my VPN address |
