# Live Scan Notes

The `scan-crypto-spreads.ps1` script compares public spot ticker prices from several venues.

Current supported sources:

- Binance book ticker.
- OKX ticker.
- KuCoin level 1 order book.
- Coinbase spot price.

Default assets:

- BTC
- ETH
- SOL
- XRP
- DOGE
- ADA
- AVAX
- LINK
- LTC
- BCH
- DOT
- TRX

Use a proxy if direct access is blocked:

```powershell
.\scan-crypto-spreads.ps1 -Proxy http://127.0.0.1:10808
```

Export CSV and Markdown report:

```powershell
.\scan-crypto-spreads.ps1 -Proxy http://127.0.0.1:10808 -ExportCsv latest-spread-watch.csv -ReportPath latest-spread-watch.md
```

Stricter scan with a manual transfer/fixed-cost estimate and USDT-only venues:

```powershell
.\scan-crypto-spreads.ps1 -Proxy http://127.0.0.1:10808 -TransferCostUsd 0.25 -MinNetUsd 0.25 -StrictUsdtOnly -ExportCsv latest-spread-watch.csv -ReportPath latest-spread-watch.md
```

Wider scan example:

```powershell
$assets = @("BTC","ETH","SOL","XRP","DOGE","ADA","AVAX","LINK","LTC","BCH","DOT","TRX","BNB","NEAR","ATOM","FIL","ETC","OP","ARB","SUI","UNI","AAVE","INJ","SEI","WLD","PEPE","SHIB","XLM","HBAR","ICP","ALGO","VET","RENDER","STX","IMX","GRT","ENS","MKR","LDO","RUNE","APT","TIA","JUP")
.\scan-crypto-spreads.ps1 -Proxy http://127.0.0.1:10808 -TransferCostUsd 0.25 -MinNetUsd 0.25 -StrictUsdtOnly -Assets $assets -ExportCsv latest-spread-watch.csv -ReportPath latest-spread-watch.md
```

## What It Calculates

- Best observed buy ask.
- Best observed sell bid.
- Raw spread.
- Raw spread percentage.
- Estimated fee cost.
- Manual transfer/fixed-cost estimate.
- Estimated net spread after trading fees and transfer/fixed cost.
- Estimated cycles needed to reach $100 when a row remains positive.

## What It Does Not Include

- Live withdrawal-fee lookup.
- Deposit delays.
- KYC/account limits.
- Liquidity beyond top of book.
- USD/USDT basis risk.
- Taxes.
- Slippage during execution.
- Counterparty or platform risk.

Do not trade just because a raw spread looks positive.

## Funding Rate Scan

The `scan-funding-rates.ps1` script checks public funding-rate endpoints for simple spot-long/perp-short observation.

```powershell
.\scan-funding-rates.ps1 -Proxy http://127.0.0.1:10808 -TradeUsd 100 -FeePercentPerSide 0.1 -MinAnnualizedPct 20 -MaxIntervalsToCoverFees 6 -ExportCsv latest-funding-watch.csv -ReportPath latest-funding-watch.md
```

It estimates:

- Funding rate per interval.
- Approximate annualized funding rate.
- Funding dollars per interval and per day on a chosen trade size.
- Estimated entry/exit fee burden.
- Funding intervals needed to cover estimated fees.

It does not include basis movement, liquidation risk, borrow costs, margin requirements, exchange risk, taxes, unavailable markets, or execution slippage.

## GitHub Bounty Watch

The `scan-github-bounties.ps1` script checks seeded public GitHub issue URLs and looks for cash-like bounty language.

```powershell
.\scan-github-bounties.ps1 -Proxy http://127.0.0.1:10808 -MinUsd 10 -ExportCsv latest-bounty-watch.csv -ReportPath latest-bounty-watch.md
```

Search-assisted scan:

```powershell
$queries = @(
  'state:open "Bounty: $100" -security -exploit -CVE -attack -red',
  'state:open "$100 bounty" "pull request" -security -exploit -CVE -attack',
  'state:open "bounty" "USDC" "pull request" -security -exploit -CVE -attack',
  'state:open "bounty" "$50" "good first issue" -security -exploit -CVE -attack'
)
.\scan-github-bounties.ps1 -Proxy http://127.0.0.1:10808 -MinUsd 10 -SearchQueries $queries -MaxSearchResultsPerQuery 5 -SearchDelaySec 7 -ExportCsv latest-bounty-watch.csv -ReportPath latest-bounty-watch.md
```

It estimates:

- XLM/USD bounty value when XLM rewards are detected.
- BTC/USD value when sats rewards are detected.
- USD reward value when direct cash amounts are detected.
- Whether an issue appears closed.
- Whether the reward appears non-cash.
- Whether the repository bounty program appears paused.
- Whether the issue requires external-account setup before work can start.
- Whether the reward meets a minimum candidate value.

The latest included search-assisted scan checked 20 issue URLs and found 0 direct candidates above the $10 threshold after status and friction filters. The largest cash-like issue was 250,000 sats, about $154.32 at scan time, but it requires AIBTC identity, external account setup, and GitHub issue claiming before work can start. A $100 SecuritySkills issue was skipped because the repository bounty program is marked paused, and a $100 Memanto issue was watch-listed because it requires external service/BountyHub participation.

It does not create forks, open pull requests, reserve bounties, verify maintainer payout history, complete external account setup, or guarantee acceptance.

## Polymarket Complete-Set Watch

The `scan-polymarket-complete-sets.ps1` script checks public Polymarket Gamma markets and public CLOB orderbooks for a narrow long-only complete-set condition.

```powershell
.\scan-polymarket-complete-sets.ps1 -Proxy http://127.0.0.1:10808 -MaxMarkets 120 -MinLiquidity 250 -MinVolume 500 -MinEdgePerSet 0.005 -MinExecutableEdgeUsd 0.25 -ExportCsv latest-polymarket-watch.csv -ReportPath latest-polymarket-watch.md
```

It estimates:

- The sum of displayed outcome prices from Gamma market data.
- The sum of current best asks from CLOB orderbooks when token IDs are available.
- Whether buying every mutually exclusive outcome appears to cost less than 1.00 before fees and execution friction.
- Approximate top-of-book depth for a full complete-set attempt.

The latest included scan checked 100 fetched markets through the proxy, generated 93 orderbook rows, and found 0 orderbook-edge candidates. The closest rows still had best-ask sums above 1.00, so the action was no-go/watch rather than trade.

It does not place trades, sign orders, move funds, bypass eligibility restrictions, account for all fees, guarantee simultaneous fills, verify settlement rules, or guarantee profit. If a location is restricted by Polymarket or local law, do not trade there.
