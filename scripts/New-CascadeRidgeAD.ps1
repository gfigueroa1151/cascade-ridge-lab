# New-CascadeRidgeAD.ps1
# Phase 4: builds the Cascade Ridge OU structure, groups, employees and a separate admin account.
# Run on the domain controller in an elevated PowerShell. Safe to run more than once: it skips anything that exists.
# No passwords are stored here; the script asks for them at run time.

Import-Module ActiveDirectory
$Domain = (Get-ADDomain).DistinguishedName
$UpnSuffix = "cascaderidgelogistics.com"
$Company = "Cascade Ridge Logistics"

# 1. Add the public domain as a sign-in (UPN) suffix
Set-ADForest -Identity (Get-ADForest) -UPNSuffixes @{Add = $UpnSuffix} -ErrorAction SilentlyContinue

# 2. OUs
function New-OU($Name, $Path) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -SearchScope OneLevel)) {
        New-ADOrganizationalUnit -Name $Name -Path $Path
        Write-Host "Created OU $Name" -ForegroundColor Green
    }
}
New-OU "CascadeRidge" $Domain
$Root = "OU=CascadeRidge,$Domain"
foreach ($ou in "Users","Groups","Admin Accounts","Workstations","Servers","Service Accounts") { New-OU $ou $Root }
foreach ($dept in "Exec","Finance","HR","Sales","Ops","IT") { New-OU $dept "OU=Users,$Root" }

# 3. Groups
$GroupOU = "OU=Groups,$Root"
foreach ($g in "grp-exec","grp-finance","grp-hr","grp-sales","grp-ops","grp-it-admins") {
    if (-not (Get-ADGroup -Filter "Name -eq '$g'")) {
        New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path $GroupOU
        Write-Host "Created group $g" -ForegroundColor Green
    }
}

# 4. Employees
$UserPw = Read-Host "Temporary password for employee accounts" -AsSecureString
$Employees = @(
    @{Sam="dana.reyes";      First="Dana";   Last="Reyes";    Title="CEO";                   Dept="Exec";    Group="grp-exec"}
    @{Sam="marcus.lee";      First="Marcus"; Last="Lee";      Title="Finance Manager";       Dept="Finance"; Group="grp-finance"}
    @{Sam="priya.shah";      First="Priya";  Last="Shah";     Title="HR Coordinator";        Dept="HR";      Group="grp-hr"}
    @{Sam="tom.becker";      First="Tom";    Last="Becker";   Title="Sales Rep";             Dept="Sales";   Group="grp-sales"}
    @{Sam="jordan.kim";      First="Jordan"; Last="Kim";      Title="Operations Lead";       Dept="Ops";     Group="grp-ops"}
    @{Sam="carlos.figueroa"; First="Carlos"; Last="Figueroa"; Title="IT and Security Admin"; Dept="IT";      Group="grp-it-admins"}
)
foreach ($e in $Employees) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($e.Sam)'")) {
        New-ADUser -Name "$($e.First) $($e.Last)" -GivenName $e.First -Surname $e.Last `
            -SamAccountName $e.Sam -UserPrincipalName "$($e.Sam)@$UpnSuffix" `
            -DisplayName "$($e.First) $($e.Last)" -Title $e.Title -Department $e.Dept -Company $Company `
            -Path "OU=$($e.Dept),OU=Users,$Root" -AccountPassword $UserPw `
            -ChangePasswordAtLogon $true -Enabled $true
        Add-ADGroupMember -Identity $e.Group -Members $e.Sam
        Write-Host "Created user $($e.Sam)" -ForegroundColor Green
    }
}

# 5. Separate admin account (admin tasks only, never synced to the cloud)
if (-not (Get-ADUser -Filter "SamAccountName -eq 'adm-carlos'")) {
    $AdminPw = Read-Host "Password for adm-carlos (Domain Admin)" -AsSecureString
    New-ADUser -Name "adm-carlos" -SamAccountName "adm-carlos" -UserPrincipalName "adm-carlos@corp.cascaderidgelogistics.com" `
        -DisplayName "Carlos Figueroa (Admin)" -Description "Domain admin account. Admin tasks only." `
        -Path "OU=Admin Accounts,$Root" -AccountPassword $AdminPw -Enabled $true
    Add-ADGroupMember -Identity "Domain Admins" -Members "adm-carlos"
    Write-Host "Created adm-carlos and added to Domain Admins" -ForegroundColor Green
}

Write-Host "`nDone." -ForegroundColor Cyan
