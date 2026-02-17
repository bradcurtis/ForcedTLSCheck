# Dot-source the functions file
. "$PSScriptRoot\Check-TlsCsv.Functions.ps1"

$domain = 'hotmail.com'
Write-Host "Running TLS check for domain: $domain"

# Run with proxy checker
Write-Host "Using proxy checker (ssl-tools.net):"
$proxyChecker = New-ProxyTlsChecker
$proxyResult = & $proxyChecker.CheckTls $domain
Write-Host "Proxy TLS Supported: $proxyResult"

# Run with native checker
Write-Host "Using native checker (direct SMTP):"
$nativeChecker = New-NativeTlsChecker
$nativeResult = & $nativeChecker.CheckTls $domain
Write-Host "Native TLS Supported: $nativeResult"
