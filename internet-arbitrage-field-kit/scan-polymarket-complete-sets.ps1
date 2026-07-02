param(
    [string]$Proxy = "",
    [int]$MaxMarkets = 80,
    [int]$PageSize = 100,
    [int]$Offset = 0,
    [decimal]$MinLiquidity = 500,
    [decimal]$MinVolume = 500,
    [decimal]$MinEdgePerSet = 0.01,
    [decimal]$MinExecutableEdgeUsd = 0.25,
    [int]$MaxOutcomes = 8,
    [int]$OrderBookDelayMs = 100,
    [int]$TimeoutSec = 20,
    [switch]$SkipOrderBooks,
    [string]$ExportCsv = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$script:InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function Convert-ToDecimal {
    param(
        $Value,
        $Default = 0
    )

    if ($null -eq $Value) {
        return $Default
    }

    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $Default
    }

    try {
        return [decimal]::Parse($text, [System.Globalization.NumberStyles]::Float, $script:InvariantCulture)
    } catch {
        return $Default
    }
}

function Format-Dec {
    param(
        $Value,
        [int]$Digits = 4
    )

    if ($null -eq $Value) {
        return ""
    }

    return ([Math]::Round([decimal]$Value, $Digits)).ToString("0." + ("0" * $Digits), $script:InvariantCulture)
}

function Convert-ToArray {
    param($Value)

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return @()
        }

        try {
            return @($Value | ConvertFrom-Json)
        } catch {
            return @()
        }
    }

    if ($Value -is [System.Array]) {
        return @($Value)
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        return @($Value)
    }

    return @($Value)
}

function Invoke-Json {
    param([string]$Uri)

    $request = @{
        Uri = $Uri
        TimeoutSec = $TimeoutSec
        Headers = @{
            "User-Agent" = "codex-polymarket-complete-set-watch/1.0"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
        $request.Proxy = $Proxy
    }

    Invoke-RestMethod @request
}

function Get-GammaMarkets {
    $markets = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $currentOffset = $Offset

    while ($markets.Count -lt $MaxMarkets) {
        $take = [Math]::Min($PageSize, $MaxMarkets - $markets.Count)
        $uri = "https://gamma-api.polymarket.com/markets?active=true&closed=false&archived=false&limit=$take&offset=$currentOffset"
        $page = @(Invoke-Json $uri)

        if ($page.Count -eq 0) {
            break
        }

        $beforeCount = $markets.Count

        foreach ($market in $page) {
            $key = if ($market.conditionId) { [string]$market.conditionId } else { [string]$market.id }
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $markets.Add($market)
            }

            if ($markets.Count -ge $MaxMarkets) {
                break
            }
        }

        if ($markets.Count -eq $beforeCount) {
            break
        }

        if ($page.Count -lt $take) {
            break
        }

        $currentOffset += $page.Count
    }

    return $markets.ToArray()
}

function Get-TopOfBook {
    param([string]$TokenId)

    $book = Invoke-Json "https://clob.polymarket.com/book?token_id=$TokenId"
    $asks = @($book.asks)
    $bids = @($book.bids)

    $bestAsk = $asks | Sort-Object { Convert-ToDecimal $_.price 999 } | Select-Object -First 1
    $bestBid = $bids | Sort-Object { Convert-ToDecimal $_.price 0 } -Descending | Select-Object -First 1

    [PSCustomObject]@{
        TokenId = $TokenId
        BestAsk = if ($bestAsk) { Convert-ToDecimal $bestAsk.price $null } else { $null }
        BestAskSize = if ($bestAsk) { Convert-ToDecimal $bestAsk.size 0 } else { $null }
        BestBid = if ($bestBid) { Convert-ToDecimal $bestBid.price $null } else { $null }
        BestBidSize = if ($bestBid) { Convert-ToDecimal $bestBid.size 0 } else { $null }
        TickSize = if ($book.tick_size) { [string]$book.tick_size } else { "" }
        MinOrderSize = if ($book.min_order_size) { [string]$book.min_order_size } else { "" }
    }
}

function Escape-Markdown {
    param($Value)

    if ($null -eq $Value) {
        return ""
    }

    return ([string]$Value).Replace("|", "\|").Replace("`r", " ").Replace("`n", " ")
}

$scanStarted = Get-Date
$warnings = New-Object System.Collections.Generic.List[string]
$results = New-Object System.Collections.Generic.List[object]

Write-Host "Polymarket Complete-Set Watch"
Write-Host ("Max markets: {0}" -f $MaxMarkets)
Write-Host ("Minimum liquidity: `${0}" -f (Format-Dec $MinLiquidity 2))
Write-Host ("Minimum volume: `${0}" -f (Format-Dec $MinVolume 2))
Write-Host ("Minimum edge per complete set: `${0}" -f (Format-Dec $MinEdgePerSet 4))
Write-Host ("Minimum executable edge at top of book: `${0}" -f (Format-Dec $MinExecutableEdgeUsd 4))
if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
    Write-Host "Proxy: $Proxy"
}
Write-Host ""

$markets = Get-GammaMarkets
$eligibleMarkets = 0
$orderBookRows = 0

foreach ($market in $markets) {
    $liquidity = Convert-ToDecimal $(if ($market.liquidityNum) { $market.liquidityNum } else { $market.liquidity }) 0
    $volume = Convert-ToDecimal $(if ($market.volumeNum) { $market.volumeNum } else { $market.volume }) 0

    if ($liquidity -lt $MinLiquidity -or $volume -lt $MinVolume) {
        continue
    }

    $outcomes = Convert-ToArray $market.outcomes
    $prices = Convert-ToArray $market.outcomePrices
    $tokenIds = Convert-ToArray $market.clobTokenIds

    if ($outcomes.Count -lt 2) {
        continue
    }

    if ($outcomes.Count -gt $MaxOutcomes) {
        $warnings.Add(("Skipped {0}: {1} outcomes exceeds MaxOutcomes {2}" -f $market.slug, $outcomes.Count, $MaxOutcomes))
        continue
    }

    $eligibleMarkets += 1

    $priceSum = $null
    if ($prices.Count -eq $outcomes.Count) {
        $priceSum = [decimal]0
        foreach ($price in $prices) {
            $priceSum += Convert-ToDecimal $price 0
        }
    }

    $askSum = $null
    $edgePerSet = $null
    $edgePct = $null
    $topDepthSets = $null
    $edgeAtTopUsd = $null
    $askParts = New-Object System.Collections.Generic.List[string]
    $bidParts = New-Object System.Collections.Generic.List[string]
    $bookOk = $false
    $bookError = ""

    if (-not $SkipOrderBooks.IsPresent -and $market.enableOrderBook -and $tokenIds.Count -eq $outcomes.Count) {
        try {
            $bookRows = New-Object System.Collections.Generic.List[object]
            for ($i = 0; $i -lt $tokenIds.Count; $i += 1) {
                if ($i -gt 0 -and $OrderBookDelayMs -gt 0) {
                    Start-Sleep -Milliseconds $OrderBookDelayMs
                }

                $top = Get-TopOfBook ([string]$tokenIds[$i])
                if ($null -eq $top.BestAsk) {
                    throw ("No ask for token {0}" -f $tokenIds[$i])
                }

                $bookRows.Add($top)
                $askParts.Add(("{0}={1} ({2})" -f $outcomes[$i], (Format-Dec $top.BestAsk 4), (Format-Dec $top.BestAskSize 2)))
                if ($null -ne $top.BestBid) {
                    $bidParts.Add(("{0}={1} ({2})" -f $outcomes[$i], (Format-Dec $top.BestBid 4), (Format-Dec $top.BestBidSize 2)))
                }
            }

            $askSum = [decimal]0
            $topDepthSets = $null
            foreach ($row in $bookRows) {
                $askSum += [decimal]$row.BestAsk
                if ($null -eq $topDepthSets -or [decimal]$row.BestAskSize -lt $topDepthSets) {
                    $topDepthSets = [decimal]$row.BestAskSize
                }
            }

            $edgePerSet = [decimal]1 - $askSum
            $edgePct = $edgePerSet * 100
            $edgeAtTopUsd = $edgePerSet * $topDepthSets
            $bookOk = $true
            $orderBookRows += 1
        } catch {
            $bookError = $_.Exception.Message
            $warnings.Add(("Orderbook failed for {0}: {1}" -f $market.slug, $bookError))
        }
    } elseif (-not $SkipOrderBooks.IsPresent) {
        $bookError = "Orderbook disabled or token count mismatch"
    }

    $priceEdge = if ($null -ne $priceSum) { [decimal]1 - $priceSum } else { $null }
    $decision = "NO INDICATIVE EDGE"

    if ($bookOk) {
        if ($edgePerSet -ge $MinEdgePerSet -and $edgeAtTopUsd -ge $MinExecutableEdgeUsd) {
            $decision = "WATCH ORDERBOOK EDGE"
        } elseif ($edgePerSet -gt 0) {
            $decision = "WATCH SMALL EDGE"
        } else {
            $decision = "NO LONG COMPLETE-SET EDGE"
        }
    } elseif ($null -ne $priceEdge -and $priceEdge -ge $MinEdgePerSet) {
        $decision = "WATCH INDICATIVE ONLY"
    }

    $url = if ($market.slug) { "https://polymarket.com/market/$($market.slug)" } else { "" }

    $results.Add([PSCustomObject]@{
        Question = [string]$market.question
        Slug = [string]$market.slug
        Url = $url
        Outcomes = $outcomes.Count
        Liquidity = [Math]::Round($liquidity, 2)
        Volume = [Math]::Round($volume, 2)
        PriceSum = if ($null -ne $priceSum) { [Math]::Round($priceSum, 6) } else { $null }
        PriceEdgePerSet = if ($null -ne $priceEdge) { [Math]::Round($priceEdge, 6) } else { $null }
        AskSum = if ($null -ne $askSum) { [Math]::Round($askSum, 6) } else { $null }
        EdgePerSet = if ($null -ne $edgePerSet) { [Math]::Round($edgePerSet, 6) } else { $null }
        EdgePct = if ($null -ne $edgePct) { [Math]::Round($edgePct, 4) } else { $null }
        TopDepthSets = if ($null -ne $topDepthSets) { [Math]::Round($topDepthSets, 4) } else { $null }
        EdgeAtTopUsd = if ($null -ne $edgeAtTopUsd) { [Math]::Round($edgeAtTopUsd, 4) } else { $null }
        BestAsks = ($askParts -join "; ")
        BestBids = ($bidParts -join "; ")
        EnableOrderBook = [bool]$market.enableOrderBook
        AcceptingOrders = [bool]$market.acceptingOrders
        Restricted = [bool]$market.restricted
        NegRisk = [bool]$market.negRisk
        EndDate = [string]$market.endDate
        Decision = $decision
        Notes = $bookError
    })
}

$sorted = @($results | Sort-Object @{ Expression = { if ($null -ne $_.AskSum) { $_.AskSum } else { 999 } }; Ascending = $true }, @{ Expression = { if ($null -ne $_.PriceSum) { $_.PriceSum } else { 999 } }; Ascending = $true })
$watchRows = @($sorted | Where-Object { $_.Decision -like "WATCH*" })
$orderBookCandidates = @($sorted | Where-Object { $_.Decision -eq "WATCH ORDERBOOK EDGE" })

Write-Host ("Markets fetched: {0}" -f $markets.Count)
Write-Host ("Markets after liquidity/volume/outcome filters: {0}" -f $eligibleMarkets)
Write-Host ("Orderbook rows generated: {0}" -f $orderBookRows)
Write-Host ("Watch rows: {0}" -f $watchRows.Count)
Write-Host ("Orderbook edge candidates: {0}" -f $orderBookCandidates.Count)
Write-Host ""

if ($sorted.Count -gt 0) {
    $sorted |
        Select-Object -First 20 Question, Outcomes, Liquidity, Volume, PriceSum, AskSum, EdgePerSet, TopDepthSets, EdgeAtTopUsd, Decision |
        Format-Table -AutoSize
} else {
    Write-Host "No rows generated."
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "Warnings:"
    foreach ($warning in ($warnings | Select-Object -First 20)) {
        Write-Host "- $warning"
    }
    if ($warnings.Count -gt 20) {
        Write-Host ("- ... {0} more warnings" -f ($warnings.Count - 20))
    }
}

Write-Host ""
Write-Host "Important: This scan is read-only and observational. It does not place trades, sign orders, bypass eligibility restrictions, account for all fees, guarantee simultaneous execution, or guarantee settlement. Do not trade where prohibited for your location."

if (-not [string]::IsNullOrWhiteSpace($ExportCsv)) {
    $sorted | Export-Csv -LiteralPath $ExportCsv -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host "Exported CSV:"
    Write-Host (Resolve-Path -LiteralPath $ExportCsv)
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Polymarket Complete-Set Watch")
    $lines.Add("")
    $lines.Add(("Scan time: {0}" -f $scanStarted.ToString("yyyy-MM-dd HH:mm:ss zzz")))
    $lines.Add("")
    $lines.Add("This is a read-only prediction-market scanner. It looks for markets where buying every mutually exclusive outcome at the current best ask appears to cost less than 1.00 before execution friction.")
    $lines.Add("")
    $lines.Add("It does not place trades, sign orders, move funds, bypass eligibility restrictions, account for all fees, guarantee simultaneous fills, or guarantee settlement. Do not trade where prohibited for your location.")
    $lines.Add("")
    $lines.Add("## Settings")
    $lines.Add("")
    $lines.Add(("- Max markets: {0}" -f $MaxMarkets))
    $lines.Add(("- Minimum liquidity: `${0}" -f (Format-Dec $MinLiquidity 2)))
    $lines.Add(("- Minimum volume: `${0}" -f (Format-Dec $MinVolume 2)))
    $lines.Add(("- Minimum edge per complete set: `${0}" -f (Format-Dec $MinEdgePerSet 4)))
    $lines.Add(("- Minimum executable edge at top of book: `${0}" -f (Format-Dec $MinExecutableEdgeUsd 4)))
    $lines.Add(("- Max outcomes per market: {0}" -f $MaxOutcomes))
    $lines.Add(("- Skip orderbooks: {0}" -f $SkipOrderBooks.IsPresent))
    if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
        $lines.Add(("- Proxy: {0}" -f $Proxy))
    }
    $lines.Add("")
    $lines.Add("## Summary")
    $lines.Add("")
    $lines.Add(("- Markets fetched: {0}" -f $markets.Count))
    $lines.Add(("- Markets after liquidity/volume/outcome filters: {0}" -f $eligibleMarkets))
    $lines.Add(("- Orderbook rows generated: {0}" -f $orderBookRows))
    $lines.Add(("- Watch rows: {0}" -f $watchRows.Count))
    $lines.Add(("- Orderbook edge candidates: {0}" -f $orderBookCandidates.Count))
    $lines.Add("")

    if ($orderBookCandidates.Count -eq 0) {
        $lines.Add("No scanned market met the orderbook-edge threshold at the current best asks.")
        $lines.Add("")
    }

    $lines.Add("## Top Rows")
    $lines.Add("")
    $lines.Add("| Question | Outcomes | Price Sum | Ask Sum | Edge/Set | Top Depth | Edge At Top | Decision | Link |")
    $lines.Add("| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |")
    foreach ($row in ($sorted | Select-Object -First 25)) {
        $lines.Add(("| {0} | {1} | {2} | {3} | {4} | {5} | `${6} | {7} | [open]({8}) |" -f (Escape-Markdown $row.Question), $row.Outcomes, (Format-Dec $row.PriceSum 4), (Format-Dec $row.AskSum 4), (Format-Dec $row.EdgePerSet 4), (Format-Dec $row.TopDepthSets 2), (Format-Dec $row.EdgeAtTopUsd 4), $row.Decision, $row.Url))
    }
    $lines.Add("")

    $lines.Add("## Best Asks For Watch Rows")
    $lines.Add("")
    if ($watchRows.Count -eq 0) {
        $lines.Add("No watch rows in this scan.")
    } else {
        foreach ($row in ($watchRows | Select-Object -First 10)) {
            $lines.Add(("- {0}: {1}" -f (Escape-Markdown $row.Question), (Escape-Markdown $row.BestAsks)))
        }
    }
    $lines.Add("")

    if ($warnings.Count -gt 0) {
        $lines.Add("## Warnings")
        $lines.Add("")
        foreach ($warning in ($warnings | Select-Object -First 30)) {
            $lines.Add(("- {0}" -f (Escape-Markdown $warning)))
        }
        if ($warnings.Count -gt 30) {
            $lines.Add(("- ... {0} more warnings" -f ($warnings.Count - 30)))
        }
        $lines.Add("")
    }

    $lines.Add("## Interpretation")
    $lines.Add("")
    $lines.Add("- `Ask Sum` below 1.00 is the only row type this scanner treats as a possible long-only complete-set edge.")
    $lines.Add("- `Price Sum` is only an indicative Gamma-market signal. It is not enough to trade.")
    $lines.Add("- A real trade still needs account eligibility, sufficient depth, fees/slippage checks, and a way to buy all outcomes without leg risk.")
    $lines.Add("- If your location is restricted by Polymarket or local law, do not trade.")
    $lines.Add("")

    $lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
    Write-Host ""
    Write-Host "Exported report:"
    Write-Host (Resolve-Path -LiteralPath $ReportPath)
}
