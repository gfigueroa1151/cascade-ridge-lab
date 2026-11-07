# New-CascadeRidgeData.ps1
# Phase 4: fills the Cascade Ridge department shares with realistic FAKE company files.
# Every name, company, number and amount here is invented for a cybersecurity lab.
# Run after Connect-AzAccount on a machine that can reach the private endpoint.

$rg = "rg-workloads"; $sa = "stcrfiles01"
$key = (Get-AzStorageAccountKey -ResourceGroupName $rg -Name $sa)[0].Value
$cred = New-Object System.Management.Automation.PSCredential("localhost\$sa", (ConvertTo-SecureString $key -AsPlainText -Force))
$rand = New-Object System.Random 2026   # fixed seed so the data is the same every run

function Write-Share($Share, [hashtable]$Files) {
    New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$sa.file.core.windows.net\$Share" -Credential $cred -Persist | Out-Null
    foreach ($name in $Files.Keys) {
        $path = Join-Path "Z:\" $name
        $dir = Split-Path $path
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-Content -Path $path -Value $Files[$name] -Encoding UTF8
    }
    Write-Host "Wrote $($Files.Count) files to $Share" -ForegroundColor Green
    Remove-PSDrive Z
}

$vendors   = "Larchmont Pallet Co.","Kestrel Bay Packaging","Silverpine Fuel Services","Tumwater Tire and Brake","Northfork Office Supply","Cedar Hollow Insurance Group","Rainshadow IT Services","Bluestem Uniform Rental"
$customers = "Harbor Lane Grocers","Copperline Hardware","Mossrock Brewing","Alder Point Medical Supply","Glacier View Furniture","Summit Ridge Outfitters","Driftwood Home Goods","Fernbrook Nursery","Stonegate Auto Parts","Westwind Pet Supply"
$cities    = "Olympia","Tacoma","Seattle","Portland","Spokane","Yakima","Bellingham","Vancouver"

# ---------- FINANCE ----------
$inv = @("InvoiceNumber,Vendor,InvoiceDate,DueDate,AmountUSD,Status")
for ($i = 1; $i -le 40; $i++) {
    $d = (Get-Date "2026-07-01").AddDays($rand.Next(0, 120))
    $inv += "INV-2026-{0:D4},{1},{2:yyyy-MM-dd},{3:yyyy-MM-dd},{4},{5}" -f (1000 + $i), $vendors[$rand.Next($vendors.Count)], $d, $d.AddDays(30), [math]::Round($rand.Next(250, 18000) + $rand.NextDouble(), 2), (@("Paid","Paid","Open","Overdue")[$rand.Next(4)])
}
$payroll = @(
    "EmployeeID,Name,Title,Department,AnnualSalaryUSD,PayFrequency,BankAccountLast4",
    "CR-1001,Dana Reyes,CEO,Exec,185000,Biweekly,4471",
    "CR-1002,Marcus Lee,Finance Manager,Finance,98000,Biweekly,2290",
    "CR-1003,Priya Shah,HR Coordinator,HR,64000,Biweekly,8812",
    "CR-1004,Tom Becker,Sales Rep,Sales,58000,Biweekly,3307",
    "CR-1005,Jordan Kim,Operations Lead,Ops,82000,Biweekly,5164",
    "CR-1006,Carlos Figueroa,IT and Security Admin,IT,88000,Biweekly,7025"
)
$budget = @("Category,Q1,Q2,Q3,Q4,TotalFY2027",
    "Fuel,142000,151000,158000,149000,600000",
    "Fleet Maintenance,38000,41000,39000,44000,162000",
    "Payroll,155000,155000,158000,158000,626000",
    "Warehouse Lease,27000,27000,27000,27000,108000",
    "Insurance,18500,18500,18500,18500,74000",
    "IT and Software,9200,9200,11800,9200,39400",
    "Marketing,6000,8500,7000,12000,33500")
$vendorList = @("Vendor,ContactEmail,PaymentTerms,PreferredMethod")
foreach ($v in $vendors) { $vendorList += "{0},billing@{1}.example,Net 30,ACH" -f $v, (($v -replace '[^a-zA-Z]', '').ToLower()) }
Write-Share "finance" @{
    "AccountsPayable\Invoices_2026_H2.csv" = $inv
    "Payroll\Payroll_Register_Oct2026.csv" = $payroll
    "Budgets\Budget_FY2027_Draft.csv"      = $budget
    "Vendors\Approved_Vendor_List.csv"     = $vendorList
    "README.txt" = "Finance department share. Payroll files are confidential. Questions: Marcus Lee."
}

# ---------- HR ----------
$roster = @("EmployeeID,Name,Title,Department,Manager,StartDate,Office",
    "CR-1001,Dana Reyes,CEO,Exec,,2019-03-04,Olympia",
    "CR-1002,Marcus Lee,Finance Manager,Finance,Dana Reyes,2020-06-15,Olympia",
    "CR-1003,Priya Shah,HR Coordinator,HR,Dana Reyes,2022-01-10,Olympia",
    "CR-1004,Tom Becker,Sales Rep,Sales,Dana Reyes,2023-04-03,Remote (Tacoma)",
    "CR-1005,Jordan Kim,Operations Lead,Ops,Dana Reyes,2021-09-20,Olympia",
    "CR-1006,Carlos Figueroa,IT and Security Admin,IT,Dana Reyes,2024-02-12,Olympia")
Write-Share "hr-dept" @{
    "Employees\Employee_Roster.csv" = $roster
    "Policies\PTO_Policy.txt" = "Cascade Ridge Logistics PTO Policy`r`nFull-time employees accrue 6.15 hours of PTO per pay period (160 hours per year).`r`nRequests over 3 days need manager approval two weeks in advance."
    "Policies\Remote_Work_Policy.txt" = "Remote employees must connect through the company VPN and keep their laptop updated.`r`nCompany data may not be stored on personal devices."
    "Templates\Offer_Letter_Template.txt" = "[Date]`r`n`r`nDear [Candidate Name],`r`n`r`nCascade Ridge Logistics is pleased to offer you the position of [Title] at an annual salary of [Salary].`r`nPlease sign and return by [Date].`r`n`r`nPriya Shah, HR Coordinator"
    "Reviews\Performance_Review_Schedule_2026.csv" = @("Employee,Reviewer,DueDate", "Marcus Lee,Dana Reyes,2026-12-05", "Priya Shah,Dana Reyes,2026-12-05", "Tom Becker,Dana Reyes,2026-12-12", "Jordan Kim,Dana Reyes,2026-12-12", "Carlos Figueroa,Dana Reyes,2026-12-19")
}

# ---------- SALES ----------
$custList = @("AccountID,Customer,City,ContactEmail,AnnualFreightSpendUSD,AccountOwner")
for ($i = 0; $i -lt $customers.Count; $i++) {
    $custList += "ACCT-{0:D3},{1},{2},shipping@{3}.example,{4},Tom Becker" -f (100 + $i), $customers[$i], $cities[$rand.Next($cities.Count)], (($customers[$i] -replace '[^a-zA-Z]', '').ToLower()), $rand.Next(12000, 240000)
}
$pipeline = @("Opportunity,Customer,Stage,EstimatedValueUSD,CloseMonth")
foreach ($c in ($customers | Select-Object -First 6)) { $pipeline += "{0} - 2027 Contract,{0},{1},{2},{3}" -f $c, (@("Prospecting","Proposal","Negotiation","Verbal Yes")[$rand.Next(4)]), $rand.Next(20000, 150000), (@("Dec 2026","Jan 2027","Feb 2027")[$rand.Next(3)]) }
Write-Share "sales" @{
    "Customers\Customer_List.csv" = $custList
    "Pipeline\Q4_2026_Pipeline.csv" = $pipeline
    "Pricing\Freight_Rate_Card_2026.csv" = @("Lane,RatePerMileUSD,MinimumChargeUSD", "Olympia-Seattle,3.10,450", "Olympia-Portland,2.95,520", "Olympia-Spokane,2.80,900", "Tacoma-Yakima,2.85,640", "Seattle-Bellingham,3.25,410")
}

# ---------- OPS ----------
$ship = @("ShipmentID,Customer,Origin,Destination,PickupDate,TruckID,Status")
for ($i = 1; $i -le 30; $i++) {
    $ship += "SHP-{0:D5},{1},{2},{3},{4:yyyy-MM-dd},TRK-{5:D2},{6}" -f (24000 + $i), $customers[$rand.Next($customers.Count)], "Olympia", $cities[$rand.Next($cities.Count)], (Get-Date "2026-11-01").AddDays($rand.Next(0, 30)), $rand.Next(1, 13), (@("Scheduled","In Transit","Delivered")[$rand.Next(3)])
}
$fleet = @("TruckID,Make,Year,Odometer,LastServiceDate,NextServiceDue")
for ($t = 1; $t -le 12; $t++) { $fleet += "TRK-{0:D2},{1},{2},{3},{4:yyyy-MM-dd},{5:yyyy-MM-dd}" -f $t, (@("Freightliner","Kenworth","Peterbilt","Volvo")[$rand.Next(4)]), $rand.Next(2016, 2025), $rand.Next(40000, 410000), (Get-Date "2026-08-01").AddDays($rand.Next(0, 80)), (Get-Date "2026-11-15").AddDays($rand.Next(0, 90)) }
Write-Share "ops" @{
    "Dispatch\Shipment_Schedule_Nov2026.csv" = $ship
    "Fleet\Fleet_Maintenance_Log.csv" = $fleet
    "Warehouse\Dock_Safety_Checklist.txt" = "Daily dock checklist: wheel chocks set, dock plates inspected, forklift pre-shift check signed, spill kit stocked."
}

# ---------- EXEC ----------
Write-Share "exec" @{
    "Board\Board_Meeting_Notes_Oct2026.txt" = "Cascade Ridge Logistics Board Meeting, October 2026`r`nAttendees: Dana Reyes (CEO), Marcus Lee (Finance)`r`n- Q3 revenue up 8 percent over Q2.`r`n- Approved purchase of two additional trucks in Q1 2027.`r`n- Discussed possible expansion into Boise. Keep confidential until announced."
    "Strategy\Strategic_Plan_2027.txt" = "2027 priorities:`r`n1. Grow contract freight revenue 15 percent.`r`n2. Open a satellite yard in Spokane.`r`n3. Complete the cybersecurity program (MFA, monitoring, incident response plan)."
    "Strategy\Acquisition_Target_CONFIDENTIAL.txt" = "Preliminary discussions with a regional carrier about a possible acquisition. Do not share outside the executive team."
}

# ---------- PUBLIC ----------
Write-Share "public" @{
    "Company_Holidays_2026.txt" = "Company holidays 2026: New Year's Day, Memorial Day, Independence Day, Labor Day, Thanksgiving and the day after, Christmas Day."
    "IT_Help_Desk_Guide.txt" = "Need IT help? Email Carlos Figueroa. Never share your password or MFA codes with anyone, including IT. Report suspicious emails right away."
    "Welcome_New_Employees.txt" = "Welcome to Cascade Ridge Logistics! Your manager will set up your first-day orientation. The employee handbook is available from HR."
}

Write-Host "`nAll fake company data written." -ForegroundColor Cyan
