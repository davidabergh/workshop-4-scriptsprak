# Where we pick the info from our files
$Root = "network_configs"

# Getting the info from files
$files = Get-ChildItem -Path $Root -Recurse -File -Include *.conf, *.rules, *.log

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

$perExt =
$files |
Group-Object Extension |
Sort-Object Name |
ForEach-Object { "{0,-8} {1,5}" -f $_.Name, $_.Count } |
Out-String

# Starting the report string here to separate it from the script as a whole
$report = @"
NETWORK CONFIGS REPORT
======================
Exportdatum : $($exportDate.ToString('yyyy-MM-dd HH:mm'))
Rot         : $Root
Antal filer : $($files.Count)
Total storlek: $totalMB MB

Per filtillägg:
$perExt
Detaljer:
---------
$detailTable
"@


$report | Set-Content 'security_audit.txt' -Encoding UTF8