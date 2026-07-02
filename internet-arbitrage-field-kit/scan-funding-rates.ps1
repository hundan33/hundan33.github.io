param(
    [string]$Proxy = "",
    [decimal]$TradeUsd = 100,
    [decimal]$FeePercentPerSide = 0.1,
    [decimal]$MinAnnualizedPct = 20,
    [int]$MaxIntervalsToCoverFees = 6,
    [string[]]$Assets = @("BTC", "ETH", "SOL", "XRP", "DOGE", "ADA", "AVAX", "LINK", "LTC", "BCH", "DOT", "TRX", "BNB", "NEAR", "ATOM", "FIL", "ETC", "OP", "ARB", "SUI", "UNI", "AAVE", "INJ", "SEI", "WLD", "PEPE", "SHIB", "XLM", "HBAR", "ICP", "ALGO", "VET", "RENDER", "STX", "IMX", "GRT", "ENS", "LDO", "RUNE", "APT", "TIA", "JUP"),
    [int]$TimeoutSec = 20,
    [string]$ExportCsv = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"

function Invoke-Json {
    param([string]$Uri)

    $request = @{
        Uri = $Uri
        TimeoutSec = $TimeoutSec
    }

    if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
        $request.Proxy = $Proxy
    }

    Invoke-RestMethod @request
}

function Add-FundingRow {
    param(
        [System.Collections.Generic.List[object]]$Rows,
        [string]$Asset,
        [string]$Venue,
        [decimal]$FundingRate,
        [decimal]$IntervalHours,
        [string]$NextFundingTime,
        [string]$Pair
    )

    $intervalsPerDay = if ($IntervalHours -gt 0) { 24 / $IntervalHours } else { 3 }
    $annualizedPct = $FundingRate * $intervalsPerDay * 365 * 100
    $fundingUsdPerInterval = $TradeUsd * $FundingRate
    $fundingUsdPerDay = $fundingUsdPerInterval * $intervalsPerDay
    $entryExitFeesUsd = $TradeUsd * (($FeePercentPerSide * 4) / 100)
    $absFundingPerInterval = [Math]::Abs($fundingUsdPerInterval)
    $intervalsToCoverFees = if ($absFundingPerInterval -gt 0) { [int][Math]::Ceiling($entryExitFeesUsd / $absFundingPerInterval) } else { $null }
    $simpleReceiveSide = if ($FundingRate -gt 0) { "Short perp receives" } elseif ($FundingRate -lt 0) { "Long perp receives" } else { "Flat" }

    $decision = if ($FundingRate -le 0) {
        "NOT SIMPLE CASH-CARRY"
    } elseif ($annualizedPct -ge $MinAnnualizedPct -and $intervalsToCoverFees -le $MaxIntervalsToCoverFees) {
        "CANDIDATE WATCH"
    } else {
        "WATCH TOO SMALL"
    }

    $Rows.Add([PSCustomObject]@{
        Asset = $Asset
        Venue = $Venue
        Pair = $Pair
        FundingRatePct = [Math]::Round($FundingRate * 100, 6)
        IntervalHours = [Math]::Round($IntervalHours, 2)
        AnnualizedPct = [Math]::Round($annualizedPct, 2)
        FundingUsdPerInterval = [Math]::Round($fundingUsdPerInterval, 5)
        FundingUsdPerDay = [Math]::Round($fundingUsdPerDay, 5)
        EstimatedEntryExitFeesUsd = [Math]::Round($entryExitFeesUsd, 4)
        IntervalsToCoverFees = $intervalsToCoverFees
        SimpleReceiveSide = $simpleReceiveSide
        NextFundingTime = $NextFundingTime
        Decision = $decision
    })
}

function Get-BinanceFunding {
    param([string]$Asset, [System.Collections.Generic.List[object]]$Rows, [System.Collections.Generic.List[string]]$Warnings)

    try {
        $symbol = "$($Asset)USDT"
        $data = Invoke-Json "https://fapi.binance.com/fapi/v1/premiumIndex?symbol=$symbol"
        Add-FundingRow $Rows $Asset "Binance Futures" ([decimal]$data.lastFundingRate) 8 ([string]$data.nextFundingTime) $symbol
    } catch {
        $Warnings.Add("Binance Futures ${Asset}: $($_.Exception.Message)")
    }
}

function Get-BybitFunding {
    param([string]$Asset, [System.Collections.Generic.List[object]]$Rows, [System.Collections.Generic.List[string]]$Warnings)

    try {
        $symbol = "$($Asset)USDT"
        $data = Invoke-Json "https://api.bybit.com/v5/market/tickers?category=linear&symbol=$symbol"
        if ($data.retCode -ne 0 -or -not $data.result.list) {
            throw "Unexpected Bybit response"
        }
        $row = $data.result.list[0]
        $intervalHours = if ($row.fundingIntervalHour) { [decimal]$row.fundingIntervalHour } else { 8 }
        Add-FundingRow $Rows $Asset "Bybit Linear" ([decimal]$row.fundingRate) $intervalHours ([string]$row.nextFundingTime) $symbol
    } catch {
        $Warnings.Add("Bybit Linear ${Asset}: $($_.Exception.Message)")
    }
}

function Get-OkxFunding {
    param([string]$Asset, [System.Collections.Generic.List[object]]$Rows, [System.Collections.Generic.List[string]]$Warnings)

    try {
        $pair = "$Asset-USDT-SWAP"
        $data = Invoke-Json "https://www.okx.com/api/v5/public/funding-rate?instId=$pair"
        if ($data.code -ne "0" -or -not $data.data) {
            throw "Unexpected OKX response"
        }
        $row = $data.data[0]
        Add-FundingRow $Rows $Asset "OKX Swap" ([decimal]$row.fundingRate) 8 ([string]$row.fundingTime) $pair
    } catch {
        $Warnings.Add("OKX Swap ${Asset}: $($_.Exception.Message)")
    }
}

$rows = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[string]
$scanStarted = Get-Date

foreach ($asset in $Assets) {
    Get-BinanceFunding $asset $rows $warnings
    Get-BybitFunding $asset $rows $warnings
    Get-OkxFunding $asset $rows $warnings
}

$sorted = @($rows | Sort-Object AnnualizedPct -Descending)
$candidates = @($sorted | Where-Object { $_.Decision -eq "CANDIDATE WATCH" })

Write-Host "Funding Rate Scan"
Write-Host ("Trade size: `${0:N2}" -f $TradeUsd)
Write-Host ("Assumed fee per side: {0:N4}%" -f $FeePercentPerSide)
Write-Host ("Minimum annualized rate: {0:N2}%" -f $MinAnnualizedPct)
Write-Host ("Max funding intervals to cover estimated entry/exit fees: {0}" -f $MaxIntervalsToCoverFees)
if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
    Write-Host "Proxy: $Proxy"
}
Write-Host ""

if ($sorted.Count -gt 0) {
    $sorted | Select-Object -First 30 | Format-Table -AutoSize
} else {
    Write-Host "No funding rows generated."
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "Warnings:"
    foreach ($warning in $warnings) {
        Write-Host "- $warning"
    }
}

Write-Host ""
Write-Host "Important: This scan is observational. It does not include basis movement, liquidation risk, borrow costs, margin requirements, exchange risk, taxes, unavailable markets, or execution slippage. Positive funding can disappear before a hedge is opened."

if (-not [string]::IsNullOrWhiteSpace($ExportCsv)) {
    $sorted | Export-Csv -LiteralPath $ExportCsv -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host "Exported CSV:"
    Write-Host (Resolve-Path -LiteralPath $ExportCsv)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("# Funding Rate Watch")
    $lines.Add("")
    $lines.Add(("Scan time: {0}" -f $scanStarted.ToString("yyyy-MM-dd HH:mm:ss zzz")))
    $lines.Add("")
    $lines.Add(("Trade size: `${0:N2}" -f $TradeUsd))
    $lines.Add(("Assumed fee per side: {0:N4}%" -f $FeePercentPerSide))
    $lines.Add(("Minimum annualized rate: {0:N2}%" -f $MinAnnualizedPct))
    $lines.Add(("Max funding intervals to cover estimated entry/exit fees: {0}" -f $MaxIntervalsToCoverFees))
    if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
        $lines.Add(("Proxy: {0}" -f $Proxy))
    }
    $lines.Add("")
    $lines.Add("## Summary")
    $lines.Add("")
    $lines.Add(("Assets scanned: {0}" -f ($Assets -join ", ")))
    $lines.Add(("Rows generated: {0}" -f $rows.Count))
    $lines.Add(("Candidate watch rows: {0}" -f $candidates.Count))
    if ($candidates.Count -eq 0) {
        $lines.Add("")
        $lines.Add("No row met the minimum annualized-rate and fee-recovery filters for a simple spot-long/perp-short funding strategy.")
    }
    $lines.Add("")
    $lines.Add("## Top Rows")
    $lines.Add("")
    $lines.Add("| Asset | Venue | Pair | Funding % | Annualized % | Funding/Interval $ | Funding/Day $ | Est Fees $ | Intervals To Cover Fees | Receive Side | Decision |")
    $lines.Add("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |")

    foreach ($row in ($sorted | Select-Object -First 30)) {
        $intervals = if ($null -ne $row.IntervalsToCoverFees) { $row.IntervalsToCoverFees } else { "" }
        $lines.Add(("| {0} | {1} | {2} | {3}% | {4}% | `${5} | `${6} | `${7} | {8} | {9} | {10} |" -f $row.Asset, $row.Venue, $row.Pair, $row.FundingRatePct, $row.AnnualizedPct, $row.FundingUsdPerInterval, $row.FundingUsdPerDay, $row.EstimatedEntryExitFeesUsd, $intervals, $row.SimpleReceiveSide, $row.Decision))
    }

    $lines.Add("")
    $lines.Add("## Warnings")
    $lines.Add("")
    if ($warnings.Count -gt 0) {
        foreach ($warning in $warnings) {
            $lines.Add("- $warning")
        }
    } else {
        $lines.Add("- No API warnings.")
    }

    $lines.Add("")
    $lines.Add("## Important")
    $lines.Add("")
    $lines.Add("This report is observational. It does not include basis movement, liquidation risk, borrow costs, margin requirements, exchange risk, taxes, unavailable markets, or execution slippage. Positive funding can disappear before a hedge is opened.")

    Set-Content -LiteralPath $ReportPath -Value $lines -Encoding UTF8
    Write-Host ""
    Write-Host "Exported report:"
    Write-Host (Resolve-Path -LiteralPath $ReportPath)
}
