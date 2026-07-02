# Internet Arbitrage Field Kit

A lightweight kit for evaluating online price spreads before wasting time or money.

It does not place trades, move funds, use private keys, or guarantee profit. It helps answer one practical question:

`After all fees, is this spread still worth doing?`

## Files

- `spread-profit-calculator.html` - offline calculator for price spread, fees, slippage, ROI, and units needed to reach $100.
- `scan-crypto-spreads.ps1` - optional read-only crypto spot spread scanner using public ticker APIs, manual transfer-cost estimates, and minimum-net filters.
- `scan-funding-rates.ps1` - optional read-only funding-rate scanner for simple spot-long/perp-short cash-and-carry observation.
- `scan-github-bounties.ps1` - optional read-only GitHub bounty issue scanner with proxy support and minimum-USD filters.
- `internet-arbitrage-map.md` - low-complexity online arbitrage categories and what to avoid.
- `opportunity-radar.md` - prioritized opportunity paths by complexity, blocker, and fit.
- `opportunity-ledger.csv` - spreadsheet-style log for tracking opportunities and results.
- `deal-evaluation-checklist.md` - before-you-act checklist.
- `no-go-rules.md` - rules for avoiding scams, spam, ToS abuse, and bad-risk deals.
- `listing-copy.md` - product listing copy.
- `share-posts.md` - short posts for distribution.
- `articles/` - public guide pages for the bounty scanner, spread calculator, and funding-rate watch.

## Suggested Price

- $19 standalone.
- $29 if bundled with custom trackers or extra examples.
- Bonus inside a larger "online money sprint" bundle.

## Good Use Cases

- Digital product bundle pricing.
- Marketplace-to-marketplace spread checks.
- Affiliate or referral campaign ROI checks.
- Crypto spot spread observation without executing trades.
- GitHub issue bounty triage.
- SaaS/API cost-vs-resale calculations.
- Domain/content/productized-service opportunity triage.

## Important

This is not financial advice, legal advice, tax advice, or a promise of profit. It is a calculator and checklist kit.

## Optional Live Scan

If public APIs are reachable, run:

```powershell
.\scan-crypto-spreads.ps1 -Proxy http://127.0.0.1:10808
```

For a stricter USDT-only scan with an assumed fixed transfer cost:

```powershell
.\scan-crypto-spreads.ps1 -Proxy http://127.0.0.1:10808 -TransferCostUsd 0.25 -MinNetUsd 0.25 -StrictUsdtOnly -ExportCsv latest-spread-watch.csv -ReportPath latest-spread-watch.md
```

The scan is observational only. It does not place trades or move funds.

The latest included spread watch uses a wider asset list and records whether any observed row remains positive after the manual cost assumptions.

Optional funding-rate scan:

```powershell
.\scan-funding-rates.ps1 -Proxy http://127.0.0.1:10808 -ExportCsv latest-funding-watch.csv -ReportPath latest-funding-watch.md
```

The funding scan is observational only. It does not place trades, open hedges, or account for liquidation risk.

Optional GitHub bounty scan:

```powershell
.\scan-github-bounties.ps1 -Proxy http://127.0.0.1:10808 -MinUsd 10 -ExportCsv latest-bounty-watch.csv -ReportPath latest-bounty-watch.md
```

Optional search-assisted bounty scan:

```powershell
$queries = @(
  'state:open "Bounty: $100" -security -exploit -CVE -attack -red',
  'state:open "$100 bounty" "pull request" -security -exploit -CVE -attack',
  'state:open "bounty" "USDC" "pull request" -security -exploit -CVE -attack',
  'state:open "bounty" "$50" "good first issue" -security -exploit -CVE -attack'
)
.\scan-github-bounties.ps1 -Proxy http://127.0.0.1:10808 -MinUsd 10 -SearchQueries $queries -MaxSearchResultsPerQuery 5 -SearchDelaySec 7 -ExportCsv latest-bounty-watch.csv -ReportPath latest-bounty-watch.md
```

The bounty scan is observational only. It checks seeded public issue URLs, can optionally discover more URLs through GitHub Search, estimates cash-like reward value, filters closed/non-cash/paused/external-account issues, and still requires a valid fork/PR/claim workflow before any payout is real.

## Public Guides

- `articles/github-bounty-scanner.html` - how the GitHub bounty scanner filters cash-like rewards and account friction.
- `articles/spread-profit-calculator.html` - how to use fee math before acting on a spread.
- `articles/funding-rate-watch.html` - how to interpret funding-rate rows before considering cash-and-carry work.
