param(
    [string]$Proxy = "",
    [decimal]$MinUsd = 10,
    [int]$TimeoutSec = 30,
    [decimal]$XlmUsd = 0,
    [string[]]$SeedUrls = @(
        "https://github.com/cocohub-mobileapp/cocohub-main/issues/45",
        "https://github.com/cocohub-mobileapp/cocohub-main/issues/46",
        "https://github.com/cocohub-mobileapp/cocohub-main/issues/48",
        "https://github.com/cocohub-mobileapp/cocohub-main/issues/50",
        "https://github.com/Ikalus1988/MisakaNet/issues/258",
        "https://github.com/auscaster/frantic-board/issues/63"
    ),
    [string]$ExportCsv = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"

function Invoke-Text {
    param([string]$Uri)

    $request = @{
        Uri = $Uri
        TimeoutSec = $TimeoutSec
        Headers = @{ "User-Agent" = "codex-bounty-watch" }
    }

    if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
        $request.Proxy = $Proxy
    }

    (Invoke-WebRequest @request).Content
}

function Invoke-Json {
    param([string]$Uri)

    $request = @{
        Uri = $Uri
        TimeoutSec = $TimeoutSec
        Headers = @{ "User-Agent" = "codex-bounty-watch" }
    }

    if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
        $request.Proxy = $Proxy
    }

    Invoke-RestMethod @request
}

function Convert-JsonStringLiteral {
    param([string]$JsonLiteral)
    ConvertFrom-Json ('"' + $JsonLiteral + '"')
}

function Get-IssueBodyFromHtml {
    param([string]$Html)

    $match = [regex]::Match($Html, '"articleBody":"(?<body>(?:\\.|[^"\\])*)"', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) {
        return Convert-JsonStringLiteral $match.Groups["body"].Value
    }

    return ""
}

function Get-TitleFromHtml {
    param([string]$Html)

    $match = [regex]::Match($Html, '<title>(?<title>.*?)</title>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) {
        return (($match.Groups["title"].Value -replace '\s+', ' ') -replace '\s+\S+\s+GitHub$', '').Trim()
    }

    return ""
}

function Get-Reward {
    param([string]$Title, [string]$Body, [decimal]$CurrentXlmUsd)

    $text = "$Title`n$Body"
    $xlmMatch = [regex]::Match($text, '(?i)(?:bounty|reward)\s*:\s*(?<amount>\d+(?:\.\d+)?)\s*XLM')
    if ($xlmMatch.Success) {
        $amount = [decimal]$xlmMatch.Groups["amount"].Value
        return [PSCustomObject]@{
            RewardAmount = $amount
            RewardCurrency = "XLM"
            ApproxUsd = [Math]::Round($amount * $CurrentXlmUsd, 4)
            CashLike = $true
        }
    }

    $workerMatch = [regex]::Match($text, '(?i)worker price\s*:\s*\$?(?<amount>\d+(?:\.\d+)?)')
    if ($workerMatch.Success) {
        $amount = [decimal]$workerMatch.Groups["amount"].Value
        return [PSCustomObject]@{
            RewardAmount = $amount
            RewardCurrency = "USD"
            ApproxUsd = [Math]::Round($amount, 4)
            CashLike = $true
        }
    }

    $usdMatch = [regex]::Match($text, '(?i)(?:bounty|reward|payout)\s*:\s*\$?(?<amount>\d+(?:\.\d+)?)\s*(?:USD|USDC)?')
    if ($usdMatch.Success) {
        $amount = [decimal]$usdMatch.Groups["amount"].Value
        return [PSCustomObject]@{
            RewardAmount = $amount
            RewardCurrency = "USD"
            ApproxUsd = [Math]::Round($amount, 4)
            CashLike = $true
        }
    }

    return [PSCustomObject]@{
        RewardAmount = $null
        RewardCurrency = "UNKNOWN"
        ApproxUsd = 0
        CashLike = $false
    }
}

if ($XlmUsd -le 0) {
    try {
        $price = Invoke-Json "https://api.coingecko.com/api/v3/simple/price?ids=stellar&vs_currencies=usd"
        $XlmUsd = [decimal]$price.stellar.usd
    } catch {
        $XlmUsd = 0
    }
}

$scanStarted = Get-Date
$rows = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[string]

foreach ($url in ($SeedUrls | Sort-Object -Unique)) {
    try {
        $html = Invoke-Text $url
        $title = Get-TitleFromHtml $html
        $body = Get-IssueBodyFromHtml $html
        $reward = Get-Reward $title $body $XlmUsd
        $closed = $body -match '(?i)status\s*:\s*closed' -or $title -match '(?i)\bclosed\b'
        $nonCash = -not $reward.CashLike

        $decision = if ($closed) {
            "SKIP CLOSED"
        } elseif ($nonCash) {
            "SKIP NON-CASH"
        } elseif ($reward.ApproxUsd -lt $MinUsd) {
            "WATCH TOO SMALL"
        } else {
            "CANDIDATE"
        }

        $summary = (($body -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 4) -join " ")

        $rows.Add([PSCustomObject]@{
            Title = $title
            Url = $url
            RewardAmount = $reward.RewardAmount
            RewardCurrency = $reward.RewardCurrency
            ApproxUsd = $reward.ApproxUsd
            StatusClosed = $closed
            CashLike = $reward.CashLike
            Decision = $decision
            Summary = $summary
        })
    } catch {
        $warnings.Add("${url}: $($_.Exception.Message)")
    }
}

$sorted = @($rows | Sort-Object ApproxUsd -Descending)
$candidates = @($sorted | Where-Object { $_.Decision -eq "CANDIDATE" })

Write-Host "GitHub Bounty Watch"
Write-Host ("XLM/USD estimate: `${0:N6}" -f $XlmUsd)
Write-Host ("Minimum candidate value: `${0:N2}" -f $MinUsd)
if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
    Write-Host "Proxy: $Proxy"
}
Write-Host ""

if ($sorted.Count -gt 0) {
    $sorted | Format-Table Title, RewardAmount, RewardCurrency, ApproxUsd, Decision -AutoSize
} else {
    Write-Host "No rows generated."
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "Warnings:"
    foreach ($warning in $warnings) {
        Write-Host "- $warning"
    }
}

if (-not [string]::IsNullOrWhiteSpace($ExportCsv)) {
    $sorted | Export-Csv -LiteralPath $ExportCsv -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host "Exported CSV:"
    Write-Host (Resolve-Path -LiteralPath $ExportCsv)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("# GitHub Bounty Watch")
    $lines.Add("")
    $lines.Add(("Scan time: {0}" -f $scanStarted.ToString("yyyy-MM-dd HH:mm:ss zzz")))
    $lines.Add("")
    $lines.Add(("XLM/USD estimate: `${0:N6}" -f $XlmUsd))
    $lines.Add(("Minimum candidate value: `${0:N2}" -f $MinUsd))
    if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
        $lines.Add(("Proxy: {0}" -f $Proxy))
    }
    $lines.Add("")
    $lines.Add("## Summary")
    $lines.Add("")
    $lines.Add(("Seed URLs checked: {0}" -f $SeedUrls.Count))
    $lines.Add(("Rows generated: {0}" -f $rows.Count))
    $lines.Add(("Candidate rows: {0}" -f $candidates.Count))
    if ($candidates.Count -eq 0) {
        $lines.Add("")
        $lines.Add("No checked bounty met the minimum candidate value and status filters.")
    }

    $lines.Add("")
    $lines.Add("## Rows")
    $lines.Add("")
    $lines.Add("| Title | Reward | Approx USD | Decision | URL |")
    $lines.Add("| --- | ---: | ---: | --- | --- |")
    foreach ($row in $sorted) {
        $rewardText = if ($row.RewardAmount -ne $null) { "{0} {1}" -f $row.RewardAmount, $row.RewardCurrency } else { "unknown" }
        $lines.Add(("| {0} | {1} | `${2} | {3} | {4} |" -f ($row.Title -replace '\|', '/'), $rewardText, $row.ApproxUsd, $row.Decision, $row.Url))
    }

    $lines.Add("")
    $lines.Add("## Notes")
    $lines.Add("")
    $lines.Add("- Non-cash badge/Hall-of-Fame issues are filtered out.")
    $lines.Add("- Closed or already-claimed bounties are skipped when status text is visible.")
    $lines.Add("- A candidate still requires a valid fork/PR/claim workflow and maintainer acceptance before any payout is real.")
    $lines.Add("- XLM/USD is an estimate from a public price API at scan time; payout value can move.")

    if ($warnings.Count -gt 0) {
        $lines.Add("")
        $lines.Add("## Warnings")
        $lines.Add("")
        foreach ($warning in $warnings) {
            $lines.Add("- $warning")
        }
    }

    Set-Content -LiteralPath $ReportPath -Value $lines -Encoding UTF8
    Write-Host ""
    Write-Host "Exported report:"
    Write-Host (Resolve-Path -LiteralPath $ReportPath)
}
