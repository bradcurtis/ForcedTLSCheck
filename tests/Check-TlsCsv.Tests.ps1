
. "$PSScriptRoot\..\Check-TlsCsv.Functions.ps1"

$Global:DebugEnabled = $false

Describe 'TLS Checker' {
    It 'Sanity check: hotmail.com should support TLS (proxy)' {
        . "$PSScriptRoot\..\Check-TlsCsv.Functions.ps1"
        $checker = New-ProxyTlsChecker
        $result = & $checker.CheckTls 'hotmail.com'
        $result | Should -Be $true
    }
    It 'Sanity check: hotmail.com should support TLS (native)' {
        . "$PSScriptRoot\..\Check-TlsCsv.Functions.ps1"
        $checker = New-NativeTlsChecker
        $result = & $checker.CheckTls 'hotmail.com'
        $result | Should -Be $true
    }
    It 'Processes a CSV and returns results' {
        . "$PSScriptRoot\..\Check-TlsCsv.Functions.ps1"
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
