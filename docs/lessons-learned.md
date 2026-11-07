# Lessons Learned

Problems I hit during the build, how I fixed them, and what I'd do differently. Newest first.

[Back to README](../README.md)

| Phase | What happened | Fix and lesson |
|---|---|---|
| 4 | Marcus couldn't RDP in while his account said "must change password at next sign-in" | RDP with Network Level Authentication checks the password before the desktop loads, so there's nowhere to change it. Set the password directly for the test. **Lesson:** first sign-ins for new users belong at the console or a self-service reset, not RDP. |
| 4 | Portal Browse on the file share said "You don't have access" | Public network access is off, so only machines inside the VNet reach the files. That's the private endpoint working. **Lesson:** the portal (control plane) and the data inside (data plane) are separate paths with separate rules. |
| 4 | The ACL script failed on the first run, and hr-dept ended up with a single user in its permissions | A PowerShell drive is invisible to icacls without `-Persist`. Removed the stray user entry afterward. **Lesson:** give access to groups, never to one person. |
| 4 | A share named "hr" failed but the script printed success | Share names need at least 3 characters, and the error was only a warning. Renamed it hr-dept and used `try/catch` with `-ErrorAction Stop`. **Lesson:** a script that can't fail loudly will lie to you. |
| 4 | Audit policy showed "No Auditing" for Logon after I set it | I missed a setting and checked before Group Policy refreshed. Fixed it, ran `gpupdate /force`, verified with `auditpol`. **Lesson:** always verify on the machine, not just in the console. |
| 4 | GPMC's Settings tab was blank | IE Enhanced Security blocked the page it uses. Trusted only that one page instead of turning the protection off. |
| 4 | The LAPS schema update failed when run through `runas` | The outer shell expanded `$false` before the inner one saw it. Ran the command directly in the elevated window. |
| 4 | The VM cost estimator showed $1,161 a month for the DC | The preview estimator was wrong for that image. **Lesson:** trust the per-hour price on Review + create. |
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
