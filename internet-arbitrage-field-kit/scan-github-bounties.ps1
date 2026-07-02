param(
    [string]$Proxy = "",
    [decimal]$MinUsd = 10,
    [int]$TimeoutSec = 30,
    [decimal]$XlmUsd = 0,
    [decimal]$BtcUsd = 0,
    [string[]]$SeedUrls = @(
        "https://github.com/1btc-news/news-client/issues/33",
        "https://github.com/cocohub-mobileapp/cocohub-main/issues/45",
        "https://github.com/cocohub-mobileapp/cocohub-main/issues/46",
        "https://github.com/cocohub-mobileapp/cocohub-main/issues/48",
        "https://github.com/cocohub-mobileapp/cocohub-main/issues/50",
        "https://github.com/Ikalus1988/MisakaNet/issues/258",
        "https://github.com/moorcheh-ai/memanto/issues/770",
        "https://github.com/Scottcjn/rustchain-bounties/issues/2819",
        "https://github.com/UnitOneAI/SecuritySkills/issues/2026",
        "https://github.com/auscaster/frantic-board/issues/63"
    ),
    [string[]]$SearchQueries = @(),
    [int]$MaxSearchResultsPerQuery = 8,
    [int]$SearchDelaySec = 7,
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
        $title = (($match.Groups["title"].Value -replace '\s+', ' ') -replace '\s+\S+\s+GitHub$', '').Trim()
        return [System.Net.WebUtility]::HtmlDecode($title)
    }

    return ""
}

function Get-GitHubRepoSlug {
    param([string]$Url)

    $match = [regex]::Match($Url, 'github\.com/(?<owner>[^/]+)/(?<repo>[^/]+)/')
    if ($match.Success) {
        return ("{0}/{1}" -f $match.Groups["owner"].Value, $match.Groups["repo"].Value)
    }

    return ""
}

$repoPauseCache = @{}

function Test-RepoProgramPaused {
    param([string]$Url)

    $slug = Get-GitHubRepoSlug $Url
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return $false
    }

    if ($repoPauseCache.ContainsKey($slug)) {
        return $repoPauseCache[$slug]
    }

    $paused = $false
    foreach ($path in @("CONTRIBUTING.md", "README.md")) {
        try {
            $text = Invoke-Text ("https://raw.githubusercontent.com/{0}/HEAD/{1}" -f $slug, $path)
            if ($text -match '(?i)paid bounty program is temporarily on hold|bounty program is temporarily on hold|bounties are paused|paid bounty program.*paused') {
                $paused = $true
                break
            }
        } catch {
        }
    }

    $repoPauseCache[$slug] = $paused
    return $paused
}

function Add-UniqueUrl {
    param(
        [System.Collections.Generic.List[string]]$Urls,
        [hashtable]$Seen,
        [string]$Url
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return
    }

    if (-not $Seen.ContainsKey($Url)) {
        $Seen[$Url] = $true
        $Urls.Add($Url)
    }
}

function Get-Reward {
    param([string]$Title, [string]$Body, [decimal]$CurrentXlmUsd, [decimal]$CurrentBtcUsd)

    $text = "$Title`n$Body"
    $kSatsMatch = [regex]::Match($text, '(?i)(?<amount>\d+(?:\.\d+)?)\s*k\s*sats?')
    if ($kSatsMatch.Success) {
        $amount = [decimal]$kSatsMatch.Groups["amount"].Value * 1000
        return [PSCustomObject]@{
            RewardAmount = $amount
            RewardCurrency = "SATS"
            ApproxUsd = [Math]::Round(($amount / 100000000) * $CurrentBtcUsd, 4)
            CashLike = $true
        }
    }

    $satsMatch = [regex]::Match($text, '(?i)(?<amount>\d{1,3}(?:,\d{3})+|\d+)\s*sats?')
    if ($satsMatch.Success) {
        $amount = [decimal]($satsMatch.Groups["amount"].Value -replace ',', '')
        return [PSCustomObject]@{
            RewardAmount = $amount
            RewardCurrency = "SATS"
            ApproxUsd = [Math]::Round(($amount / 100000000) * $CurrentBtcUsd, 4)
            CashLike = $true
        }
    }

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

    $dollarMatch = [regex]::Match($text, '(?i)(?:bounty|reward|payout|requested bounty)\s*:\s*\$(?<amount>\d+(?:\.\d+)?)')
    if ($dollarMatch.Success) {
        $amount = [decimal]$dollarMatch.Groups["amount"].Value
        return [PSCustomObject]@{
            RewardAmount = $amount
            RewardCurrency = "USD"
            ApproxUsd = [Math]::Round($amount, 4)
            CashLike = $true
        }
    }

    $usdCurrencyMatch = [regex]::Match($text, '(?i)(?:bounty|reward|payout|requested bounty)\s*:\s*(?<amount>\d+(?:\.\d+)?)\s*(?:USD|USDC)\b')
    if ($usdCurrencyMatch.Success) {
        $amount = [decimal]$usdCurrencyMatch.Groups["amount"].Value
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

if ($XlmUsd -le 0 -or $BtcUsd -le 0) {
    try {
        $price = Invoke-Json "https://api.coingecko.com/api/v3/simple/price?ids=stellar,bitcoin&vs_currencies=usd"
        if ($XlmUsd -le 0) {
            $XlmUsd = [decimal]$price.stellar.usd
        }
        if ($BtcUsd -le 0) {
            $BtcUsd = [decimal]$price.bitcoin.usd
        }
    } catch {
        if ($XlmUsd -le 0) { $XlmUsd = 0 }
        if ($BtcUsd -le 0) { $BtcUsd = 0 }
    }
}

$scanStarted = Get-Date
$rows = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[string]
$scanUrls = New-Object System.Collections.Generic.List[string]
$urlSeen = @{}
$searchQueriesRun = 0
$searchUrlsAdded = 0

foreach ($seedUrl in $SeedUrls) {
    Add-UniqueUrl $scanUrls $urlSeen $seedUrl
}

foreach ($query in ($SearchQueries | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
    try {
        $encodedQuery = [uri]::EscapeDataString($query)
        $searchUri = "https://api.github.com/search/issues?q=$encodedQuery&per_page=$MaxSearchResultsPerQuery"
        $searchResult = Invoke-Json $searchUri
        $searchQueriesRun += 1

        foreach ($item in $searchResult.items) {
            if ($item.PSObject.Properties.Name -contains "pull_request") {
                continue
            }

            $before = $scanUrls.Count
            Add-UniqueUrl $scanUrls $urlSeen $item.html_url
            if ($scanUrls.Count -gt $before) {
                $searchUrlsAdded += 1
            }
        }
    } catch {
        $warnings.Add("search [$query]: $($_.Exception.Message)")
    }

    if ($SearchDelaySec -gt 0) {
        Start-Sleep -Seconds $SearchDelaySec
    }
}

foreach ($url in $scanUrls) {
    try {
        $html = Invoke-Text $url
        $title = Get-TitleFromHtml $html
        $body = Get-IssueBodyFromHtml $html
        $text = "$title`n$body"
        $reward = Get-Reward $title $body $XlmUsd $BtcUsd
        $closed = $body -match '(?i)status\s*:\s*closed' -or $title -match '(?i)\bclosed\b'
        $programPaused = $text -match '(?i)paid bounty program is temporarily on hold|bounty program is temporarily on hold|bounties are paused' -or (Test-RepoProgramPaused $url)
        $requiresExternalAccount = $text -match '(?i)aibtc\.com|AIBTC agent identity|x402|BountyHub|Sign up at|Discord|GitHub Sponsors|PayPal|BTC address|STX address'
        $longTermProject = $text -match '(?i)60-day|weekly synthesis|revenue share|onboarded|daily publishing|ongoing operations|active week'
        $securityRisk = $text -match '(?i)\bred team\b|unauthenticated RCE|Spring4Shell|DDoS|sandbox escape|request smuggling|BGP hijacking|weaponization'
        $nonCash = -not $reward.CashLike

        $decision = if ($closed) {
            "SKIP CLOSED"
        } elseif ($programPaused) {
            "SKIP PROGRAM PAUSED"
        } elseif ($nonCash) {
            "SKIP NON-CASH"
        } elseif ($requiresExternalAccount) {
            "WATCH REQUIRES ACCOUNT"
        } elseif ($longTermProject) {
            "WATCH LONG TERM"
        } elseif ($securityRisk) {
            "WATCH SECURITY RISK"
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
Write-Host ("BTC/USD estimate: `${0:N2}" -f $BtcUsd)
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
    $lines.Add(("BTC/USD estimate: `${0:N2}" -f $BtcUsd))
    $lines.Add(("Minimum candidate value: `${0:N2}" -f $MinUsd))
    if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
        $lines.Add(("Proxy: {0}" -f $Proxy))
    }
    $lines.Add("")
    $lines.Add("## Summary")
    $lines.Add("")
    $lines.Add(("Seed URLs configured: {0}" -f $SeedUrls.Count))
    $lines.Add(("Search queries run: {0}" -f $searchQueriesRun))
    $lines.Add(("Search URLs added: {0}" -f $searchUrlsAdded))
    $lines.Add(("URLs checked: {0}" -f $scanUrls.Count))
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
    $lines.Add("- External-account bounties are watch-listed instead of treated as direct candidates.")
    $lines.Add("- Sats rewards are converted with the public BTC/USD estimate at scan time.")
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
