# GitHub Bounty Scanner Mini Kit

Read-only PowerShell scanner for triaging public GitHub issue bounties before spending time on a pull request.

Suggested payment: **$9** if useful.

## Download

- [Download the mini kit](https://github.com/hundan33/hundan33.github.io/raw/main/github-bounty-scanner/downloads/github-bounty-scanner-mini-kit.zip)
- [Open the landing page](index.html)
- [Download the scanner script](scan-github-bounties.ps1)
- [Read the latest bounty watch report](latest-bounty-watch.md)
- [Download the latest bounty watch CSV](latest-bounty-watch.csv)
- [Copy sample search queries](sample-queries.md)

## Pay Or Support

EVM address:

`0x1B18F54A416cA5d77945d9E05C66E3D00020578f`

Crypto transfers are irreversible. Confirm chain and token before sending.

## What It Does

- Checks seeded public GitHub issue URLs.
- Optionally discovers more issues through GitHub Search queries.
- Estimates USD value for USD, USDC, XLM, and sats rewards.
- Watch-lists tasks that require external accounts or claim flows.
- Skips paused programs, closed issues, non-cash rewards, and too-small rewards.
- Exports CSV and Markdown reports.

## Example

```powershell
$queries = @(
  'state:open "Bounty: $100" -security -exploit -CVE -attack -red',
  'state:open "$100 bounty" "pull request" -security -exploit -CVE -attack',
  'state:open "bounty" "USDC" "pull request" -security -exploit -CVE -attack',
  'state:open "bounty" "$50" "good first issue" -security -exploit -CVE -attack'
)
.\scan-github-bounties.ps1 -Proxy http://127.0.0.1:10808 -MinUsd 10 -SearchQueries $queries -MaxSearchResultsPerQuery 5 -SearchDelaySec 7 -ExportCsv latest-bounty-watch.csv -ReportPath latest-bounty-watch.md
```

## Important

This is not a promise of payout. A candidate still requires a valid fork, pull request, claim workflow, maintainer acceptance, and payment settlement before money is real.
