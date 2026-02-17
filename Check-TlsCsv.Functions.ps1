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
            $content = $result.Content
            $oneline = $content -replace '\s+', ' '
            if ($Global:DebugEnabled) {
                Write-Log ('Proxy response for ' + $domain + ":" + $content) 'Debug'
                Write-Log ('[Debug] Normalized HTML: ' + $oneline) 'Debug'
            }
            if ($oneline -like '*text-success*' -and $oneline -like '*supported*' -and $oneline -like '*fa fa-check*') {
                return $true
            }
            return $false
        } catch {
            return $false
        }
    }
    $checker.PSTypeNames.Insert(0, 'ProxyTlsChecker')
    return $checker
}

function New-TlsCheckService {
    param($checker)
    $obj = New-Object PSObject -Property @{
        Checker = $checker
        CheckDomains = {
            param($csvPath)
            $results = @()
            $domains = Import-Csv $csvPath | Select-Object -ExpandProperty Domain
            foreach ($domain in $domains) {
                $tls = & $checker.CheckTls $domain
                $results += [PSCustomObject]@{Domain=$domain;TlsSupported=$tls}
            }
            return $results
        }
    }
    $obj.PSTypeNames.Insert(0, 'TlsCheckService')
    return $obj
}
