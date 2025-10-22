# Where we pick the info from our files
$Root = "network_configs"

# Getting the info from files
$files = Get-ChildItem -Path $Root -Recurse -File -Include *.conf, *.rules, *.log


# This will adjust LastWriteTime from the filenames so the dates will be correct
foreach ($f in $files) {
    if ($f.Extension -in '.conf', '.rules') {
        $line = Get-Content $f.FullName -TotalCount 10 | Select-String 'Last modified:'
        if ($line) {
            $dateText = $line -replace '.*Last modified:\s*', ''
            $date = [datetime]::Parse($dateText)
            [System.IO.File]::SetLastWriteTime($f.FullName, $date)
        }
    }
    elseif ($f.Extension -eq '.log' -and $f.BaseName -match '\d{4}-\d{2}-\d{2}') {
        $date = [datetime]::Parse("$($matches[0]) 00:00:00")
        [System.IO.File]::SetLastWriteTime($f.FullName, $date)
    }
}

# Counting the last week for these statistics
$now = [datetime]'2024-10-14'
$weekAgo = $now.AddDays(-7)
# Added these to make sure my string will be correct
$nowStr = $now.ToString('yyyy-MM-dd HH:mm')
$weekAgoStr = $weekAgo.ToString('yyyy-MM-dd HH:mm')

# Detailed table with the info
$detailTable =
$files |
Select-Object Name,
@{n = 'Storlek(KB)'; e = { [math]::Round($_.Length / 1KB, 1) } },
@{n = 'SenastÄndrad'; e = { $_.LastWriteTime } },
@{n = 'Mapp'; e = { $_.Directory.Name } } |
Sort-Object SenastÄndrad -Descending |
Format-Table -AutoSize | Out-String

# A quick summary
$totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
$totalMB = [math]::Round($totalBytes / 1MB, 2)

$perExt = # Counting how many addons per file (.conf, .log, .rules)
$files |
Group-Object Extension |
Sort-Object Name |
ForEach-Object { "{0,-8} {1,5}" -f $_.Name, $_.Count } |
Out-String

# Last changed files within 7 days

$recent = $files |
Where-Object { $_.LastWriteTime -ge $weekAgo -and $_.LastWriteTime -le $now } |
Sort-Object LastWriteTime -Descending

$recentBytes = ($recent | Measure-Object Length -Sum).Sum
$recentMB = [math]::Round($recentBytes / 1MB, 2)



$recentTable = if ($recent) {
    $recent | Select-Object Name,
    @{n = 'Storlek(KB)'; e = { [math]::Round($_.Length / 1KB, 1) } }, # Math makes the decimals more fitting
    @{n = 'Ändrad'; e = { $_.LastWriteTime } },
    @{n = 'Mapp'; e = { $_.Directory.Name } } |
    Format-Table -AutoSize | Out-String
}
else {
    "Inga filer ändrade i perioden ($weekAgoStr  $nowStr)."  # This came to use the first time since I didn't adjust LastWriteTime
}

# Grouping all the file types per extension and sizes

$perType = $files |
Group-Object Extension |
Select-Object Name,
@{n = 'AntalFiler'; e = { $_.Count } },
@{n = 'TotalStorlek(MB)'; e = { [math]::Round( ($_.Group | Measure-Object Length -Sum).Sum / 1MB, 2) } } |
Format-Table -AutoSize | Out-String

# Calculating top 5 biggest logfiles
$largestLogs =
$files |
Where-Object { $_.Extension -eq '.log' } |
Sort-Object Length -Descending |            # Sorted by bytes
Select-Object -First 5 Name,
@{n = 'Storlek(MB)'; e = { '{0:N4}' -f ($_.Length / 1MB) } }, # 0:N4 Added 2 extra decimals since these files are very small
@{n = 'Mapp'; e = { $_.Directory.Name } } |
Format-Table -AutoSize | Out-String


#Finding all the IP-addresses in the conf. files
$ips = $files |
Where-Object { $_.Extension -eq '.conf' } |
Select-String -Pattern '\b\d{1,3}(\.\d{1,3}){3}\b' -AllMatches | # \b\d{1,3}(\.\d{1,3}){3}\b This means 4 groups of 1-3 numbers, separated with dots like an IP address
ForEach-Object { $_.Matches.Value } |
Sort-Object -Unique

$ips = $ips |
ForEach-Object { $_.Trim() } |
Where-Object { $_ -notmatch '^(0\.0\.0\.0|255\.255\.255\.252|255\.255\.255\.0)$' } #This line removes unecessary IP addresses that are unique but not worthy of listing

$ipList = if ($ips) {
    $ips | ForEach-Object { " - $_" } | Out-String   # One row per IP like a list
}
else {
    "Inga IP-adresser hittades i .conf-filer."
}

# Keywords to search for in .log files (security-related). Used by Select-String; matching is case-insensitive.
$patterns = 'ERROR', 'FAILED', 'DENIED'

$errorsPerFile =
$files |
Where-Object { $_.Extension -eq '.log' } |
Select-String -Pattern ($patterns -join '|') -AllMatches -CaseSensitive:$false | # Makes sure for example ”error”, ”Error”, ”ERROR” counts
ForEach-Object {
    # Expanding all the matches not just the rows
    foreach ($m in $_.Matches) { $_.Path }
} |
Group-Object |
Select-Object @{n = 'Fil'; e = { Split-Path $_.Name -Leaf } }, # Just shows the file name
@{n = 'Träffar'; e = { $_.Count } } |
Sort-Object Träffar -Descending

$errorsPerFileText = if ($errorsPerFile) {
    $errorsPerFile | Format-Table -AutoSize | Out-String
}
else {
    "Inga träffar på ERROR/FAILED/DENIED i loggfilerna."
}


# This is not for the txt report, this is everything we put out to config_inventory.csv

# The root we go from
$rootPath = (Resolve-Path $Root).Path   

# Building the inventory list
$inventory = $files | Where-Object { $_.Extension -in '.conf', '.rules', '.log' } |
Select-Object `
@{n = 'Name'; e = { $_.Name } },
@{n = 'Path'; e = { [System.IO.Path]::GetRelativePath($rootPath, $_.FullName) } },
@{n = 'SizeBytes'; e = { $_.Length } },
@{n = 'Last changed'; e = { $_.LastWriteTime } }

# Export the csv file
$csvPath = Join-Path $Root 'config_inventory.csv'
$inventory | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8









# Starting the report string here to separate it from the script as a whole
$report = @"
NETWORK CONFIGS REPORT
======================
Exportdatum : $nowStr
Period (7 d)  : från $weekAgoStr till $nowStr
Rot         : $Root
Antal filer : $($files.Count)
Total storlek: $totalMB MB

Per filtillägg:
$perExt

Per filtyp (antal + total storlek):
$perType

Detaljer:
---------
$detailTable

Nyligen ändrade (senaste 7 d): 
-------------------------------
$recentTable

Största loggfiler (topp 5):
---------------------------
$largestLogs

IP-adresser från .conf-filer:
-----------------------------
$ipList

Säkerhetsvarningar i loggarna: 
------------------------------
$errorsPerFileText


"@


$report | Set-Content 'security_audit.txt' -Encoding UTF8