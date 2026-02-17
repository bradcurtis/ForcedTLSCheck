

# Check-TlsCsv.Tests.ps1
# ---------------------------------------------
# Pester test suite for ForcedTLSCheck functions.
# Validates proxy and native TLS checkers and CSV processing.
# ---------------------------------------------

# Load all TLS checker functions for testing
. "$PSScriptRoot\..\Check-TlsCsv.Functions.ps1"

# Disable debug logging for tests
$Global:DebugEnabled = $false

Describe 'TLS Checker' {
    # Test proxy checker for a known TLS-supporting domain
    It 'Sanity check: hotmail.com should support TLS (proxy)' {
        . "$PSScriptRoot\..\Check-TlsCsv.Functions.ps1"
        $checker = New-ProxyTlsChecker
        $result = & $checker.CheckTls 'hotmail.com'
        $result | Should -Be $true
    }
    # Test native checker for a known domain (may fail if SMTP blocked)
    It 'Sanity check: hotmail.com should support TLS (native)' {
        . "$PSScriptRoot\..\Check-TlsCsv.Functions.ps1"
        $checker = New-NativeTlsChecker
        $result = & $checker.CheckTls 'hotmail.com'
        $result | Should -Be $true
    }
    # Test batch CSV processing with proxy checker
    It 'Processes a CSV and returns results' {
        . "$PSScriptRoot\..\Check-TlsCsv.Functions.ps1"
        # Create a temporary CSV file
        $csv = @" 
Domain
hotmail.com
yahoo.com
"@
        $csvPath = "$env:TEMP\test_domains.csv"
        $csv | Set-Content -Path $csvPath
        $checker = New-ProxyTlsChecker
        $service = New-TlsCheckService $checker
        $results = & $service.CheckDomains $csvPath
        $results | Should -Not -BeNullOrEmpty
        $results[0].Domain | Should -Be 'hotmail.com'
        Remove-Item $csvPath
    }
}
