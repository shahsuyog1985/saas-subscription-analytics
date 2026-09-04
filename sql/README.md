# SQL Practice: SaaS Subscription Analytics

Use these exercises to practice joins, conditional aggregation, CTEs, window
functions, cohort analysis, and business interpretation with the project's five
source tables.

## Schema

| Table | Grain | Useful columns |
|---|---|---|
| `accounts` | One row per customer account | `account_id`, `industry`, `country`, `employee_count`, `signup_date`, `plan` |
| `users` | One row per user | `user_id`, `account_id`, `role` |
| `subscriptions` | One current subscription per account | `account_id`, `seats`, `status`, `mrr`, `started_on`, `ended_on` |
| `invoices` | One row per invoice | `account_id`, `invoice_date`, `amount`, `status` |
| `support_tickets` | One row per ticket | `account_id`, `opened_at`, `priority`, `category`, `satisfaction_score`, `resolution_hours`, `resolved_at` |

## Level 1: Core aggregation

### 1. Account distribution by plan

Return each plan's account count and percentage of all accounts.

**Expected columns:** `plan`, `account_count`, `account_share`

### 2. Subscription status summary

Count active, churned, trialing, and past-due subscriptions.

**Expected columns:** `status`, `subscription_count`, `status_share`

### 3. Active MRR by plan

Calculate active accounts, active MRR, and average MRR per active account for
each plan.

**Expected columns:** `plan`, `active_accounts`, `active_mrr`, `active_arpa`

### 4. Account seat utilization

Count linked users for each account and divide that count by licensed seats.
Retain accounts with no users.

**Expected columns:** `account_id`, `company_name`, `plan`, `users`, `seats`,
`seat_utilization`

### 5. Invoice collection

Summarize invoice count and amount by invoice status, including each status's
share of total invoice value.

**Expected columns:** `status`, `invoice_count`, `invoice_amount`,
`amount_share`

## Level 2: Business segmentation

### 6. Highest-value active accounts

Find the 20 active accounts with the highest MRR. Include company, industry,
country, plan, seats, and employee count.

### 7. Churn by plan

Calculate total accounts, churned accounts, and snapshot logo churn for each
plan.

**Hint:** Conditional aggregation avoids filtering active statuses out of the
denominator.

### 8. Churn by industry

Rank industries by churn rate, retaining only industries with at least 25
accounts.

### 9. Support performance by priority

Return ticket count, open-ticket rate, median resolution hours, and average
satisfaction by priority.

### 10. Monthly invoice trend

Calculate monthly invoiced amount, paid amount, unpaid amount, and collection
rate.

### 11. Underutilized active accounts

Find active accounts using fewer than 50% of their licensed seats. Rank the
largest unused-seat opportunities first.

### 12. Account support load

Calculate tickets per 100 linked users for every account. Handle accounts with
zero users without causing a division-by-zero error.

## Level 3: Analytical SQL

### 13. Support load and churn

Divide accounts into support-load quartiles using `NTILE(4)`. Compare logo
churn across the quartiles.

**Expected columns:** `support_quartile`, `accounts`, `churned_accounts`,
`churn_rate`

### 14. Account health mart

Build one row per account containing subscription status, MRR, seat utilization,
invoice collection, ticket count, open tickets, satisfaction, and resolution
time.

**Challenge:** Avoid row multiplication when joining multiple one-to-many
tables. Aggregate each child table before joining it to accounts.

### 15. Signup cohort retention

Group accounts by signup quarter and calculate the percentage currently active.
Explain why this is snapshot retention rather than a survival curve.

### 16. Revenue concentration

Rank active accounts by MRR and calculate cumulative MRR share. Determine how
many accounts generate the first 50% and 80% of active MRR.

**Hint:** Use a running `SUM()` divided by total MRR.

### 17. Plan performance ranking

Create a plan scorecard containing active MRR, churn, median seat utilization,
average satisfaction, and support load. Rank each plan on every metric.

### 18. Active versus churned accounts

Compare employee count, seats, users, ticket volume, satisfaction, resolution
time, and invoice collection between active and churned accounts.

### 19. Invoice delinquency and churn

Determine whether accounts with at least one non-paid invoice have a higher
churn rate than accounts whose invoices are all paid.

**Challenge:** Define the account-level delinquency flag before calculating
group-level churn.

### 20. Executive SaaS scorecard

Write one query that returns:

- Active customer count
- Active MRR
- ARR run rate
- Active ARPA
- Snapshot logo churn
- Median seat utilization
- Invoice collection rate
- Open-ticket rate

## Validation targets

Use these values to check your logic without revealing the complete queries:

| Metric | Expected result |
|---|---:|
| Total accounts | 1,200 |
| Active accounts | 1,030 |
| Active MRR | $879,545 |
| ARR run rate | $10,554,540 |
| Snapshot logo churn | 7.17% |
| Median seat utilization | 76.92% |
| Paid invoice rate | 89.87% |
| Open-ticket rate | 8.41% |

## Recommended practice workflow

1. Write the simplest correct query.
2. Reconcile its totals with the validation targets.
3. Refactor complex logic into clearly named CTEs.
4. Check for duplicate rows after every join.
5. Explain the business conclusion in two sentences.
6. Identify one limitation or follow-up question.

## Analytical limitation

The subscription table records current state rather than historical MRR events.
It does not support defensible calculations of true NRR, GRR, expansion, or
contraction. Recognizing that limitation is part of the exercise.

