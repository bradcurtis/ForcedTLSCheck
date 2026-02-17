
#region Logger
#region Logger
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Debug','Info','Warn','Error')][string]$Level = 'Info'
    )
    if ($Level -eq 'Debug' -and -not $Global:DebugEnabled) { return }
    $logLine = "[$Level] $Message"
    Write-Host $logLine
    if ($Level -eq 'Debug') {
        $logPath = Join-Path $PSScriptRoot 'Debug.log'
        Add-Content -Path $logPath -Value $logLine
    }
}
#endregion
#endregion

#region Interface and Classes (PowerShell 4.0 compatible)

function New-ITlsChecker {
    param()
    $obj = New-Object PSObject -Property @{
        CheckTls = $null # method placeholder
    }
    $obj.PSTypeNames.Insert(0, 'ITlsChecker')
    return $obj
}

function New-NativeTlsChecker {
    param()
    $checker = New-ITlsChecker
    $checker.CheckTls = {
        param($domain)
        try {
            $mx = ([System.Net.Dns]::GetHostAddresses($domain))[0].ToString()
            $tcp = New-Object Net.Sockets.TcpClient($mx, 25)
            $stream = $tcp.GetStream()
            $writer = New-Object IO.StreamWriter($stream)
            $reader = New-Object IO.StreamReader($stream)
            $writer.WriteLine("EHLO test.com")
            $writer.Flush()
            $response = $reader.ReadToEnd()
            $tcp.Close()
            return ($response -match 'STARTTLS')
        } catch {
            return $false
        }
    }
    $checker.PSTypeNames.Insert(0, 'NativeTlsChecker')
    return $checker
}

function New-ProxyTlsChecker {
    param()
    $checker = New-ITlsChecker
    $checker.CheckTls = {
        param($domain)
        $url = "https://ssl-tools.net/mailservers/$domain"
        try {
            $result = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop

            # Dot-source the functions
            . "$PSScriptRoot\Check-TlsCsv.Functions.ps1"

            param(
                [string]$CsvPath,
                [string]$Domain,
                [switch]$UseProxy,
                [switch]$Debug
            )
            $Global:DebugEnabled = $Debug

            # Main logic
            if ($UseProxy) {
                $checker = New-ProxyTlsChecker
            } else {
                $checker = New-NativeTlsChecker
            }
            $service = New-TlsCheckService $checker

            if ($Domain) {
                $tls = & $checker.CheckTls $Domain
                [PSCustomObject]@{Domain=$Domain;TlsSupported=$tls} | Format-Table
            } elseif ($CsvPath) {
                $results = & $service.CheckDomains $CsvPath
                $results | Format-Table
            } else {
                Write-Host "Please provide either -Domain or -CsvPath."
            }
