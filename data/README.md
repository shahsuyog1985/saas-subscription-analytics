# Data

The source CSVs are not committed. Download them with:

```bash
python scripts/download_data.py
```

The script downloads the 717 KB archive from Misata Studio, checks its pinned
SHA-256 digest, verifies the five expected tables are present, and extracts them
to `data/raw/`.

- Source: https://www.misata.studio/datasets/saas-subscription-analytics
- License: CC0 / public domain
- Snapshot checked: 2026-08-02 (per the included integrity certificate)
- Tables: accounts, users, subscriptions, invoices, support tickets
- Rows: 44,384 total

Although the dataset is synthetic and public, excluding raw data keeps the Git
history lean and demonstrates a production-style data boundary. If the upstream
file changes, the checksum failure makes that drift visible rather than silently
changing the results.

