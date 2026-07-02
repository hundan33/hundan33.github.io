# Live Scan Notes

The `scan-crypto-spreads.ps1` script compares public spot ticker prices from several venues.

Current supported sources:

- Binance book ticker.
- OKX ticker.
- KuCoin level 1 order book.
- Coinbase spot price.

Use a proxy if direct access is blocked:

```powershell
.\scan-crypto-spreads.ps1 -Proxy http://127.0.0.1:10808
```

## What It Calculates

- Best observed buy ask.
- Best observed sell bid.
- Raw spread.
- Raw spread percentage.
- Estimated fee cost.
- Estimated net spread on a chosen trade size.

## What It Does Not Include

- Withdrawal fees.
- Deposit delays.
- KYC/account limits.
- Liquidity beyond top of book.
- USD/USDT basis risk.
- Taxes.
- Slippage during execution.
- Counterparty or platform risk.

Do not trade just because a raw spread looks positive.
