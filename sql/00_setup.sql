-- DuckDB setup: run this file from the repository root.
-- It creates views over the downloaded CSV files without importing or copying data.

CREATE OR REPLACE VIEW accounts AS
SELECT * FROM read_csv_auto('data/raw/accounts.csv', header = true);

CREATE OR REPLACE VIEW users AS
SELECT * FROM read_csv_auto('data/raw/users.csv', header = true);

CREATE OR REPLACE VIEW subscriptions AS
SELECT * FROM read_csv_auto('data/raw/subscriptions.csv', header = true);

CREATE OR REPLACE VIEW invoices AS
SELECT * FROM read_csv_auto('data/raw/invoices.csv', header = true);

CREATE OR REPLACE VIEW support_tickets AS
SELECT * FROM read_csv_auto('data/raw/support_tickets.csv', header = true);

