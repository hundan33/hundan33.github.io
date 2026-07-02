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
