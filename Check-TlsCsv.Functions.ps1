
#region Logger
# Write-Log: Outputs log messages to the console and optionally to Debug.log.
# Includes timestamp and log level. Debug messages are shown in yellow and written to file if enabled.
function Write-Log {
    param(
        [string]$Message, # The message to log
        [ValidateSet('Debug','Info','Warn','Error')][string]$Level = 'Info' # Log level
    )
    # Only log debug messages if debug is enabled
    if ($Level -eq 'Debug' -and -not $Global:DebugEnabled) { return }
    $timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $logLine = "[$timestamp][$Level] $Message"
    if ($Level -eq 'Debug') {
        # Only output to console if not HTML content
        if ($Message -notmatch '<html|<div|<table|<body|<!DOCTYPE') {
            Write-Host $logLine -ForegroundColor Yellow # Highlight debug in console
        }
        $logPath = Join-Path $PSScriptRoot 'Debug.log'
        Add-Content -Path $logPath -Value $logLine # Write to log file
    } else {
        Write-Host $logLine
    }
}
#endregion


#region Interface: ITlsChecker
# Returns a generic checker object with a CheckTls method placeholder.
function New-ITlsChecker {
    param()
    $obj = New-Object PSObject -Property @{
        CheckTls = $null # method placeholder
    }
    $obj.PSTypeNames.Insert(0, 'ITlsChecker')
    return $obj
}
#endregion


#region Native TLS Checker
# Checks for STARTTLS support by connecting directly to the domain's MX server on port 25.
# Returns true if STARTTLS is found in the SMTP response, false otherwise.
function New-NativeTlsChecker {
    param()
    $checker = New-ITlsChecker
    $checker.CheckTls = {
        param($domain) # Domain to check
        try {
            $mx = ([System.Net.Dns]::GetHostAddresses($domain))[0].ToString() # Get MX IP
            $tcp = New-Object Net.Sockets.TcpClient($mx, 25) # Connect to SMTP port
            $stream = $tcp.GetStream()
            $writer = New-Object IO.StreamWriter($stream)
            $reader = New-Object IO.StreamReader($stream)
            $writer.WriteLine("EHLO test.com") # Send EHLO
            $writer.Flush()
            $response = $reader.ReadToEnd() # Read SMTP response
            $tcp.Close()
            return ($response -match 'STARTTLS') # Look for STARTTLS
        } catch {
            return $false # Any error = not supported
        }
    }
    $checker.PSTypeNames.Insert(0, 'NativeTlsChecker')
    return $checker
}
#endregion


#region Proxy TLS Checker
# Checks for TLS support by scraping ssl-tools.net for the domain's mailserver report.
# Looks for specific HTML markers indicating TLS support.
function New-ProxyTlsChecker {
    param()
    $checker = New-ITlsChecker
    $checker.CheckTls = {
        param($domain) # Domain to check
        $url = "https://ssl-tools.net/mailservers/$domain"
        try {
            $result = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
            $content = $result.Content # Raw HTML
            $oneline = $content -replace '\s+', ' ' # Normalize whitespace
            if ($Global:DebugEnabled) {
                Write-Log ('Proxy response for ' + $domain + ":`n" + $content) 'Debug'
                Write-Log ('[Debug] Normalized HTML: ' + $oneline) 'Debug'
            }
            # Look for HTML markers indicating TLS support
            if ($oneline -like '*text-success*' -and $oneline -like '*supported*' -and $oneline -like '*fa fa-check*') {
                return $true
            }
            return $false
        } catch {
            return $false # Any error = not supported
        }
    }
    $checker.PSTypeNames.Insert(0, 'ProxyTlsChecker')
    return $checker
}
#endregion


#region TLS Check Service
# Service object for batch-checking domains from a CSV file using a checker instance.
# Returns an array of results with domain and TLS support status.
function New-TlsCheckService {
    param($checker) # Checker instance (proxy or native)
    $obj = New-Object PSObject -Property @{
        Checker = $checker
        CheckDomains = {
            param($csvPath) # Path to CSV file
            $results = @()
            $domains = Import-Csv $csvPath | Select-Object -ExpandProperty Domain # Read domains
            foreach ($domain in $domains) {
                $tls = & $checker.CheckTls $domain # Check each domain
                $results += [PSCustomObject]@{Domain=$domain;TlsSupported=$tls}
            }
            return $results
        }
    }
    $obj.PSTypeNames.Insert(0, 'TlsCheckService')
    return $obj
}
#endregion
