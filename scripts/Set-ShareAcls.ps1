# Set-ShareAcls.ps1
# Phase 4: locks each Azure Files department share to its AD group with NTFS permissions.
# Run on a domain-joined machine that can reach the private endpoint, after Connect-AzAccount.
# The storage account key is used once for this setup; it stays in memory and is never put on a command line.
$rg = "rg-workloads"; $sa = "stcrfiles01"
$key = (Get-AzStorageAccountKey -ResourceGroupName $rg -Name $sa)[0].Value
$cred = New-Object System.Management.Automation.PSCredential("localhost\$sa", (ConvertTo-SecureString $key -AsPlainText -Force))

# finance was done by hand in File Explorer (Domain Admins Full control, grp-finance Modify)
$shares = [ordered]@{
    "hr-dept" = @("CASCADERIDGE\grp-hr:(OI)(CI)M")
    "sales"   = @("CASCADERIDGE\grp-sales:(OI)(CI)M")
    "ops"     = @("CASCADERIDGE\grp-ops:(OI)(CI)M")
    "exec"    = @("CASCADERIDGE\grp-exec:(OI)(CI)M")
    "public"  = @("CASCADERIDGE\Domain Users:(OI)(CI)RX", "CASCADERIDGE\grp-it-admins:(OI)(CI)M")
}

foreach ($s in $shares.Keys) {
    # -Persist makes a real mapped drive so icacls (a separate program) can see it
    New-PSDrive -Name Y -PSProvider FileSystem -Root "\\$sa.file.core.windows.net\$s" -Credential $cred -Persist | Out-Null
    icacls "Y:\" /remove:g "BUILTIN\Users" "NT AUTHORITY\Authenticated Users" "CREATOR OWNER" | Out-Null
    icacls "Y:\" /grant "CASCADERIDGE\Domain Admins:(OI)(CI)F" @($shares[$s]) | Out-Null
    Write-Host "`n== $s ==" -ForegroundColor Cyan
    icacls "Y:\"
    Remove-PSDrive Y
}
