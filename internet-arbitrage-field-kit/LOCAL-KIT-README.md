# Internet Arbitrage Field Kit

A lightweight kit for evaluating online price spreads before wasting time or money.

It does not place trades, move funds, use private keys, or guarantee profit. It helps answer one practical question:

`After all fees, is this spread still worth doing?`

## Files

- `spread-profit-calculator.html` - offline calculator for price spread, fees, slippage, ROI, and units needed to reach $100.
- `scan-crypto-spreads.ps1` - optional read-only crypto spot spread scanner using public ticker APIs.
- `internet-arbitrage-map.md` - low-complexity online arbitrage categories and what to avoid.
- `opportunity-radar.md` - prioritized opportunity paths by complexity, blocker, and fit.
- `opportunity-ledger.csv` - spreadsheet-style log for tracking opportunities and results.
- `deal-evaluation-checklist.md` - before-you-act checklist.
- `no-go-rules.md` - rules for avoiding scams, spam, ToS abuse, and bad-risk deals.
- `listing-copy.md` - product listing copy.
- `share-posts.md` - short posts for distribution.

## Suggested Price

- $19 standalone.
- $29 if bundled with custom trackers or extra examples.
- Bonus inside a larger "online money sprint" bundle.

## Good Use Cases

- Digital product bundle pricing.
- Marketplace-to-marketplace spread checks.
- Affiliate or referral campaign ROI checks.
- Crypto spot spread observation without executing trades.
- SaaS/API cost-vs-resale calculations.
- Domain/content/productized-service opportunity triage.

## Important

This is not financial advice, legal advice, tax advice, or a promise of profit. It is a calculator and checklist kit.

## Optional Live Scan

If public APIs are reachable, run:

```powershell
.\scan-crypto-spreads.ps1 -Proxy http://127.0.0.1:10808
```

The scan is observational only. It does not place trades or move funds.
