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
@{n = 'Storlek(MB)'; e = { '{0:N4}' -f ($_.Length / 1MB) } }, # Added 2 extra decimals since these files are very small
@{n = 'Mapp'; e = { $_.Directory.Name } } |
Format-Table -AutoSize | Out-String

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
"@


$report | Set-Content 'security_audit.txt' -Encoding UTF8