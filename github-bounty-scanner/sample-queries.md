# Sample GitHub Bounty Search Queries

Use these with `scan-github-bounties.ps1 -SearchQueries`.

```powershell
$queries = @(
  'state:open "Bounty: $100" -security -exploit -CVE -attack -red',
  'state:open "$100 bounty" "pull request" -security -exploit -CVE -attack',
  'state:open "bounty" "USDC" "pull request" -security -exploit -CVE -attack',
  'state:open "bounty" "$50" "good first issue" -security -exploit -CVE -attack',
  'state:open "reward" "$100" "pull request" -security -exploit -CVE -attack',
  'state:open "paid" "good first issue" "$100" -security -exploit -CVE -attack'
)
```

Notes:

- Keep query batches small to avoid GitHub Search rate limits.
- Avoid exploit/security-heavy terms unless you are intentionally doing authorized security work.
- Treat external account tasks as watch-list items until account setup and claim rules are clear.
- Re-run with a proxy if direct access is blocked.
