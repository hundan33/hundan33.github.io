param(
    [string]$Proxy = "",
    [decimal]$TradeUsd = 100,
    [decimal]$FeePercentPerSide = 0.1,
    [decimal]$TransferCostUsd = 0,
    [decimal]$MinNetUsd = 0.25,
    [string[]]$Assets = @("BTC", "ETH", "SOL", "XRP", "DOGE", "ADA", "AVAX", "LINK", "LTC", "BCH", "DOT", "TRX"),
    [int]$TimeoutSec = 20,
    [switch]$StrictUsdtOnly,
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

function Add-Quote {
    param(
        [System.Collections.Generic.List[object]]$Quotes,
        [string]$Asset,
        [string]$Venue,
        [Nullable[decimal]]$Bid,
        [Nullable[decimal]]$Ask,
        [Nullable[decimal]]$Last,
        [string]$Pair,
        [string]$Notes = ""
    )

    if ($Bid -eq $null -and $Ask -eq $null -and $Last -eq $null) {
        return
    }

    $effectiveBid = if ($Bid -ne $null) { [decimal]$Bid } elseif ($Last -ne $null) { [decimal]$Last } else { [decimal]$Ask }
    $effectiveAsk = if ($Ask -ne $null) { [decimal]$Ask } elseif ($Last -ne $null) { [decimal]$Last } else { [decimal]$Bid }

    $Quotes.Add([PSCustomObject]@{
        Asset = $Asset
        Venue = $Venue
        Pair = $Pair
        Bid = $effectiveBid
        Ask = $effectiveAsk
        Last = if ($Last -ne $null) { [decimal]$Last } else { $null }
        Notes = $Notes
    })
}

function Get-BinanceQuote {
    param([string]$Asset, [System.Collections.Generic.List[object]]$Quotes, [System.Collections.Generic.List[string]]$Warnings)

    try {
        $symbol = "$($Asset)USDT"
        $data = Invoke-Json "https://api.binance.com/api/v3/ticker/bookTicker?symbol=$symbol"
        Add-Quote $Quotes $Asset "Binance" ([decimal]$data.bidPrice) ([decimal]$data.askPrice) $null "$Asset-USDT"
    } catch {
        $Warnings.Add("Binance ${Asset}: $($_.Exception.Message)")
    }
}

function Get-OkxQuote {
    param([string]$Asset, [System.Collections.Generic.List[object]]$Quotes, [System.Collections.Generic.List[string]]$Warnings)

    try {
        $pair = "$Asset-USDT"
        $data = Invoke-Json "https://www.okx.com/api/v5/market/ticker?instId=$pair"
        if ($data.code -ne "0" -or -not $data.data) {
            throw "Unexpected OKX response"
        }
        $row = $data.data[0]
        Add-Quote $Quotes $Asset "OKX" ([decimal]$row.bidPx) ([decimal]$row.askPx) ([decimal]$row.last) $pair
    } catch {
        $Warnings.Add("OKX ${Asset}: $($_.Exception.Message)")
    }
}

function Get-KuCoinQuote {
    param([string]$Asset, [System.Collections.Generic.List[object]]$Quotes, [System.Collections.Generic.List[string]]$Warnings)

    try {
        $pair = "$Asset-USDT"
        $data = Invoke-Json "https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=$pair"
        if ($data.code -ne "200000" -or -not $data.data) {
            throw "Unexpected KuCoin response"
        }
        Add-Quote $Quotes $Asset "KuCoin" ([decimal]$data.data.bestBid) ([decimal]$data.data.bestAsk) ([decimal]$data.data.price) $pair
    } catch {
        $Warnings.Add("KuCoin ${Asset}: $($_.Exception.Message)")
    }
}

function Get-CoinbaseQuote {
    param([string]$Asset, [System.Collections.Generic.List[object]]$Quotes, [System.Collections.Generic.List[string]]$Warnings)

    try {
        $pair = "$Asset-USD"
        $data = Invoke-Json "https://api.coinbase.com/v2/prices/$pair/spot"
        Add-Quote $Quotes $Asset "Coinbase" $null $null ([decimal]$data.data.amount) $pair "Spot midpoint only; USD vs USDT basis may differ."
    } catch {
        $Warnings.Add("Coinbase ${Asset}: $($_.Exception.Message)")
    }
}

$quotes = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[string]
$results = New-Object System.Collections.Generic.List[object]
$scanStarted = Get-Date

foreach ($asset in $Assets) {
    Get-BinanceQuote $asset $quotes $warnings
    Get-OkxQuote $asset $quotes $warnings
    Get-KuCoinQuote $asset $quotes $warnings
    if (-not $StrictUsdtOnly) {
        Get-CoinbaseQuote $asset $quotes $warnings
    }
}

$feeRoundTrip = ($FeePercentPerSide * 2) / 100

foreach ($asset in $Assets) {
    $assetQuotes = @($quotes | Where-Object { $_.Asset -eq $asset })
    if ($assetQuotes.Count -lt 2) {
        $warnings.Add("${asset}: fewer than two venues returned usable prices")
        continue
    }

    $bestBuy = $assetQuotes | Sort-Object Ask | Select-Object -First 1
    $bestSell = $assetQuotes | Sort-Object Bid -Descending | Select-Object -First 1
    $rawSpread = $bestSell.Bid - $bestBuy.Ask
    $rawSpreadPct = if ($bestBuy.Ask -gt 0) { ($rawSpread / $bestBuy.Ask) * 100 } else { 0 }
    $estimatedFeeUsd = $TradeUsd * $feeRoundTrip
    $grossSpreadUsd = if ($bestBuy.Ask -gt 0) { $TradeUsd * ($rawSpread / $bestBuy.Ask) } else { 0 }
    $netSpreadUsd = $grossSpreadUsd - $estimatedFeeUsd
    $netAfterTransferUsd = $netSpreadUsd - $TransferCostUsd
    $cyclesTo100 = if ($netAfterTransferUsd -gt 0) { [int][Math]::Ceiling(100 / $netAfterTransferUsd) } else { $null }
    $decision = if ($netAfterTransferUsd -ge $MinNetUsd) {
        "POSSIBLE AFTER COSTS"
    } elseif ($netAfterTransferUsd -gt 0) {
        "WATCH TOO SMALL"
    } else {
        "NO-GO AFTER COSTS"
    }

    $results.Add([PSCustomObject]@{
        Asset = $asset
        BuyVenue = $bestBuy.Venue
        BuyAsk = [Math]::Round($bestBuy.Ask, 6)
        SellVenue = $bestSell.Venue
        SellBid = [Math]::Round($bestSell.Bid, 6)
        RawSpread = [Math]::Round($rawSpread, 6)
        RawSpreadPct = [Math]::Round($rawSpreadPct, 4)
        GrossSpreadUsd = [Math]::Round($grossSpreadUsd, 4)
        EstimatedFeesUsd = [Math]::Round($estimatedFeeUsd, 4)
        NetSpreadUsd = [Math]::Round($netSpreadUsd, 4)
        TransferCostUsd = [Math]::Round($TransferCostUsd, 4)
        NetAfterTransferUsd = [Math]::Round($netAfterTransferUsd, 4)
        CyclesTo100 = $cyclesTo100
        Decision = $decision
    })
}

Write-Host "Crypto Spread Scan"
Write-Host ("Trade size: `${0:N2}" -f $TradeUsd)
Write-Host ("Assumed fee per side: {0:N4}%" -f $FeePercentPerSide)
Write-Host ("Assumed transfer/fixed cost: `${0:N4}" -f $TransferCostUsd)
Write-Host ("Minimum useful net after costs: `${0:N4}" -f $MinNetUsd)
if ($StrictUsdtOnly) {
    Write-Host "Strict USDT-only mode: enabled"
}
if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
    Write-Host "Proxy: $Proxy"
}
Write-Host ""

if ($results.Count -gt 0) {
    $results | Format-Table -AutoSize
} else {
    Write-Host "No spread rows generated."
}

Write-Host ""
Write-Host "Raw Quotes:"
$quotes | Sort-Object Asset, Venue | Format-Table Asset, Venue, Pair, Bid, Ask, Notes -AutoSize

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "Warnings:"
    foreach ($warning in $warnings) {
        Write-Host "- $warning"
    }
}

Write-Host ""
Write-Host "Important: This scan is observational. Transfer/fixed cost is a manual estimate. It does not verify withdrawal availability, deposit delays, KYC limits, liquidity depth beyond top of book, USD/USDT basis risk, taxes, or execution risk."

if (-not [string]::IsNullOrWhiteSpace($ExportCsv)) {
    $results | Export-Csv -LiteralPath $ExportCsv -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host "Exported CSV:"
    Write-Host (Resolve-Path -LiteralPath $ExportCsv)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $sorted = @($results | Sort-Object NetAfterTransferUsd -Descending)
    $positive = @($sorted | Where-Object { $_.NetAfterTransferUsd -gt 0 })
    $meetsThreshold = @($sorted | Where-Object { $_.NetAfterTransferUsd -ge $MinNetUsd })
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("# Crypto Spread Watch")
    $lines.Add("")
    $lines.Add(("Scan time: {0}" -f $scanStarted.ToString("yyyy-MM-dd HH:mm:ss zzz")))
    $lines.Add("")
    $lines.Add(("Trade size: `${0:N2}" -f $TradeUsd))
    $lines.Add(("Assumed fee per side: {0:N4}%" -f $FeePercentPerSide))
    $lines.Add(("Assumed transfer/fixed cost: `${0:N4}" -f $TransferCostUsd))
    $lines.Add(("Minimum useful net after costs: `${0:N4}" -f $MinNetUsd))
    $lines.Add(("Strict USDT-only mode: {0}" -f $StrictUsdtOnly.IsPresent))
    if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
        $lines.Add(("Proxy: {0}" -f $Proxy))
    }
    $lines.Add("")
    $lines.Add("## Summary")
    $lines.Add("")
    $lines.Add(("Assets scanned: {0}" -f ($Assets -join ", ")))
    $lines.Add(("Rows generated: {0}" -f $results.Count))
    $lines.Add(("Positive after estimated fees and transfer/fixed cost: {0}" -f $positive.Count))
    $lines.Add(("Rows meeting minimum useful net: {0}" -f $meetsThreshold.Count))
    $lines.Add("")

    if ($positive.Count -eq 0) {
        $lines.Add("No scanned asset remained positive after the estimated round-trip trading fees and transfer/fixed cost.")
        $lines.Add("")
    } elseif ($meetsThreshold.Count -eq 0) {
        $lines.Add("At least one row remained barely positive, but none met the minimum useful net threshold.")
        $lines.Add("")
    }

    $lines.Add("## Top Rows")
    $lines.Add("")
    $lines.Add("| Asset | Buy | Ask | Sell | Bid | Raw Spread % | Gross $ | Fees $ | Transfer $ | Net After Costs $ | Cycles To `$100 | Decision |")
    $lines.Add("| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |")

    foreach ($row in ($sorted | Select-Object -First 20)) {
        $cycles = if ($null -ne $row.CyclesTo100) { $row.CyclesTo100 } else { "" }
        $lines.Add(("| {0} | {1} | {2} | {3} | {4} | {5}% | `${6} | `${7} | `${8} | `${9} | {10} | {11} |" -f $row.Asset, $row.BuyVenue, $row.BuyAsk, $row.SellVenue, $row.SellBid, $row.RawSpreadPct, $row.GrossSpreadUsd, $row.EstimatedFeesUsd, $row.TransferCostUsd, $row.NetAfterTransferUsd, $cycles, $row.Decision))
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
    $lines.Add("This report is observational. Transfer/fixed cost is a manual estimate, not a live withdrawal-fee lookup. It does not verify withdrawal availability, deposit delays, KYC limits, liquidity depth beyond top of book, USD/USDT basis risk, taxes, or execution risk. Do not trade just because a raw spread looks positive.")

    Set-Content -LiteralPath $ReportPath -Value $lines -Encoding UTF8
    Write-Host ""
    Write-Host "Exported report:"
    Write-Host (Resolve-Path -LiteralPath $ReportPath)
}
