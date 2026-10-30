# Lessons Learned

Problems I hit during the build, how I fixed them, and what I'd do differently. Newest first.

[Back to README](../README.md)

| Phase | What happened | Fix and lesson |
|---|---|---|
| 3 | SSH to the test VM timed out even though the firewall log showed the traffic passing | VPN traffic leaves the firewall with a source (10.100.0.2) that isn't in any VNet, so it hit `DenyAllOutBound` on nsg-fw-inside. Added an outbound allow rule. **Lesson:** if the firewall says pass and nothing arrives, the drop is in Azure, and NSGs check both directions. |
| 3 | First route plan would have let mgmt traffic skip the firewall, and spoke replies to the scanner would have gone around it | Peering adds /16 routes and the most specific route wins. Added same-prefix /16 routes in rt-mgmt and a /24 for mgmt in rt-spokes. **Lesson:** check routes in both directions or traffic goes asymmetric. |
| 3 | Automatic outbound NAT only covered loopback | Giving LAN a gateway made OPNsense treat it as outside. Switched to Hybrid and added a WAN rule for 10.0.0.0/8. **Lesson:** always expand the auto-generated rules and check what they actually cover. |
| 3 | A second NSG was attached directly to the firewall's LAN NIC, and the portal's NIC list showed nothing | Found it from the VM's network settings page and dissociated it. **Lesson:** subnet and NIC NSGs stack, and both must allow the traffic. Scroll the whole page. |
| 3 | The OPNsense image labeled the WAN NIC as LAN, and the Serial Console login looked frozen | Reassigned interfaces from the console. Passwords don't echo in a terminal, and a reboot cleared the stuck prompt. **Lesson:** confirm an out-of-band path before changing network settings. |
| 3 | A VM password with a comma didn't work after a reset | Reset it without commas or quote characters. |
| 2 | Script pasted into Cloud Shell came out scrambled | Windows line endings. Saved it as a file and stripped them with `sed -i 's/\r$//'`. |
| 2 | "Subnet address range is not contained in the address space" | The new VNet still had the default address space. Set the VNet range first, then add subnets. |
| 1 | Locked my admin account out right after saving a Conditional Access block policy | Got back in with the excluded break-glass account and moved the policy to Report-only. **Lesson:** always exclude an emergency account and test block policies in Report-only. |
| 1 | Global Admin couldn't see the subscription | Entra roles and Azure RBAC are separate systems. Assigned Owner on the subscription. |
| 1 | Try and Buy buttons greyed out for the P2 trial | Licensing moved to the Microsoft 365 admin center. |
| 0 | Resource groups landed in East US | Region can't be changed after creation. Deleted and recreated them in West US. |
| 0 | Free trial said "one per customer" and credit info wouldn't load | Just provisioning delay. The credit appeared about an hour later. |
