# Where we pick the info from our files
$Root = "network_configs"

# Getting the info from files
$files = Get-ChildItem -Path $Root -Recurse -File -Include *.conf, *.rules, *.log

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

$recent = $files |
Where-Object { $_.LastWriteTime -ge $weekAgo -and $_.LastWriteTime -le $now } |
Sort-Object LastWriteTime -Descending

$recentBytes = ($recent | Measure-Object Length -Sum).Sum
$recentMB = [math]::Round($recentBytes / 1MB, 2)

$recent = $files |
Where-Object { $_.LastWriteTime -ge $weekAgo -and $_.LastWriteTime -le $now } |
Sort-Object LastWriteTime -Descending

$recentTable = if ($recent) {
    $recent | Select-Object Name,
    @{n = 'Storlek(KB)'; e = { [math]::Round($_.Length / 1KB, 1) } }, # Math makes the decimals more fitting
    @{n = 'Ändrad'; e = { $_.LastWriteTime } },
    @{n = 'Mapp'; e = { $_.Directory.Name } } |
    Format-Table -AutoSize | Out-String
}
else {
    "Inga filer ändrade i perioden ($weekAgoStr – $nowStr)."
}

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
Detaljer:
---------
$detailTable

Nyligen ändrade (senaste 7 d): 
-------------------------------
$recentTable


"@


$report | Set-Content 'security_audit.txt' -Encoding UTF8