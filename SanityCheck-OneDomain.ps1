
# SanityCheck-OneDomain.ps1
# ---------------------------------------------
# This script demonstrates how to use the ForcedTLSCheck functions
# to check if a single domain supports TLS for email delivery.
# It runs both the proxy-based and native SMTP checkers and prints results.
# ---------------------------------------------


# Load all TLS checker functions (dependency injection, logger, etc.)
. "$PSScriptRoot\Check-TlsCsv.Functions.ps1"

# Enable debug logging for full output (set to $true for verbose log, $false to disable)
$Global:DebugEnabled = $true

# Domain to check
$domain = 'hotmail.com'
Write-Host "Running TLS check for domain: $domain"


# --- Proxy Checker Example ---
Write-Host "Using proxy checker (ssl-tools.net):"
# Create a proxy checker instance
$proxyChecker = New-ProxyTlsChecker
# Run the TLS check for the domain using the proxy (with debug logging enabled)
$proxyResult = & $proxyChecker.CheckTls $domain
# Output the result
Write-Host "Proxy TLS Supported: $proxyResult"
Write-Host "(See Debug.log for full proxy response and normalized HTML)"


# --- Native Checker Example ---
Write-Host "Using native checker (direct SMTP):"
# Create a native checker instance
$nativeChecker = New-NativeTlsChecker
# Run the TLS check for the domain using direct SMTP (with debug logging enabled)
$nativeResult = & $nativeChecker.CheckTls $domain
# Output the result
Write-Host "Native TLS Supported: $nativeResult"
Write-Host "(See Debug.log for any debug output)"
