# Internet Arbitrage Field Kit

Offline calculator and checklist kit for evaluating online price spreads after fees.

Suggested payment: **$19** if useful.

## Download

- [Preview the calculator online](https://htmlpreview.github.io/?https://github.com/hundan33/hundan33.github.io/blob/main/internet-arbitrage-field-kit/spread-profit-calculator.html)
- [Download the full kit](https://github.com/hundan33/hundan33.github.io/raw/main/internet-arbitrage-field-kit/downloads/internet-arbitrage-field-kit.zip)
- [Open the calculator file](spread-profit-calculator.html)
- [Download the live scan script](scan-crypto-spreads.ps1)
- [Download the funding-rate scan script](scan-funding-rates.ps1)
- [Download the GitHub bounty scan script](scan-github-bounties.ps1)
- [Read live scan notes](live-scan-notes.md)
- [Read latest spread watch report](latest-spread-watch.md)
- [Download latest spread watch CSV](latest-spread-watch.csv)
- [Read latest funding watch report](latest-funding-watch.md)
- [Download latest funding watch CSV](latest-funding-watch.csv)
- [Read latest bounty watch report](latest-bounty-watch.md)
- [Download latest bounty watch CSV](latest-bounty-watch.csv)
- [Read the arbitrage map](internet-arbitrage-map.md)
- [Read the opportunity radar](opportunity-radar.md)
- [Read the deal checklist](deal-evaluation-checklist.md)
- [Read the no-go rules](no-go-rules.md)
- [Copy share posts](share-posts.md)

## Pay Or Support

EVM address:

`0x1B18F54A416cA5d77945d9E05C66E3D00020578f`

Crypto transfers are irreversible. Confirm chain and token before sending.

If the online preview is unavailable, download the zip and open `spread-profit-calculator.html` locally.

## What It Helps With

Raw spreads can be misleading. A deal that looks profitable can fail after:

- Platform fees.
- Payment fees.
- Fixed transaction fees.
- Transfer or network fees.
- Slippage.
- Refund/support reserve.
- Time and execution risk.

The calculator helps you estimate net profit, ROI, break-even price, and units needed to reach a target like $100.

The optional PowerShell scanner can read public ticker APIs through a local proxy and compare observed spot prices across Binance, OKX, KuCoin, and Coinbase:

```powershell
.\scan-crypto-spreads.ps1 -Proxy http://127.0.0.1:10808
```

For a stricter USDT-only scan with a manual fixed transfer-cost estimate:

```powershell
.\scan-crypto-spreads.ps1 -Proxy http://127.0.0.1:10808 -TransferCostUsd 0.25 -MinNetUsd 0.25 -StrictUsdtOnly -ExportCsv latest-spread-watch.csv -ReportPath latest-spread-watch.md
```

It is observational only. It does not place trades.

Latest published scan:

- 43 assets scanned.
- 42 usable rows generated.
- Strict USDT-only mode enabled.
- Assumed trade size: $100.
- Assumed fee: 0.1% per side.
- Assumed transfer/fixed cost: $0.25.
- 0 rows remained positive after estimated trading fees and transfer/fixed cost.
- The closest row was GRT, but it was still negative after fees and transfer/fixed cost.
- Current action is no-go/watch rather than trade.

Latest funding-rate scan:

- 42 assets scanned.
- 120 usable funding rows generated.
- 0 rows met the annualized-rate and fee-recovery filters.
- The strongest observed row was BNB on Binance Futures at about 11.93% annualized, but it still needed about 37 funding intervals to cover estimated entry/exit fees at the default assumptions.

Latest GitHub bounty scan:

- 6 seeded public issue URLs checked through the proxy.
- 0 rows met the $10 minimum candidate filter.
- The largest open cash-like issue was 35 XLM, about $6.99 at scan time.
- Closed, non-cash, and too-small issues were filtered out.

## Good For

- Digital product pricing.
- Marketplace fee comparisons.
- Affiliate/referral ROI checks.
- Crypto spot spread observation.
- GitHub issue bounty triage.
- API/data packaging ideas.
- Online-only productized workflows.

## Important

This is not financial advice, legal advice, tax advice, or a promise of profit. It does not place trades, move funds, use private keys, or guarantee any result.
