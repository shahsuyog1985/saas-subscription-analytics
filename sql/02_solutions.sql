-- Reference solutions for DuckDB. Run sql/00_setup.sql first.

-- 01. Account distribution by plan
SELECT plan,
       COUNT(*) AS account_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS account_share
FROM accounts
GROUP BY plan
ORDER BY account_count DESC;

-- 02. Subscription status summary
SELECT status,
       COUNT(*) AS subscription_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS status_share
FROM subscriptions
GROUP BY status
ORDER BY subscription_count DESC;

-- 03. Active MRR by plan
SELECT a.plan,
       COUNT(*) AS active_accounts,
       ROUND(SUM(s.mrr), 2) AS active_mrr,
       ROUND(AVG(s.mrr), 2) AS active_arpa
FROM accounts a
JOIN subscriptions s USING (account_id)
WHERE s.status = 'active'
GROUP BY a.plan
ORDER BY active_mrr DESC;

-- 04. Account seat utilization
WITH user_counts AS (
    SELECT account_id, COUNT(*) AS users
    FROM users
    GROUP BY account_id
)
SELECT a.account_id, a.company_name, a.plan,
       COALESCE(u.users, 0) AS users,
       s.seats,
       ROUND(COALESCE(u.users, 0) * 1.0 / NULLIF(s.seats, 0), 4) AS seat_utilization
FROM accounts a
JOIN subscriptions s USING (account_id)
LEFT JOIN user_counts u USING (account_id)
ORDER BY seat_utilization, a.account_id;

-- 05. Invoice collection
SELECT status,
       COUNT(*) AS invoice_count,
       ROUND(SUM(amount), 2) AS invoice_amount,
       ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (), 2) AS amount_share
FROM invoices
GROUP BY status
ORDER BY invoice_amount DESC;

-- 06. Highest-value active accounts
SELECT a.account_id, a.company_name, a.industry, a.country, a.plan,
       s.mrr, s.seats, a.employee_count
FROM accounts a
JOIN subscriptions s USING (account_id)
WHERE s.status = 'active'
ORDER BY s.mrr DESC, a.account_id
LIMIT 20;

-- 07. Churn by plan
SELECT a.plan,
       COUNT(*) AS total_accounts,
       COUNT(*) FILTER (WHERE s.status = 'churned') AS churned_accounts,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'churned') / COUNT(*), 2) AS churn_rate
FROM accounts a
JOIN subscriptions s USING (account_id)
GROUP BY a.plan
ORDER BY churn_rate DESC;

-- 08. Churn by industry
SELECT a.industry,
       COUNT(*) AS total_accounts,
       COUNT(*) FILTER (WHERE s.status = 'churned') AS churned_accounts,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'churned') / COUNT(*), 2) AS churn_rate
FROM accounts a
JOIN subscriptions s USING (account_id)
GROUP BY a.industry
HAVING COUNT(*) >= 25
ORDER BY churn_rate DESC, total_accounts DESC;

-- 09. Support performance by priority
SELECT priority,
       COUNT(*) AS ticket_count,
       ROUND(100.0 * COUNT(*) FILTER (WHERE resolved_at IS NULL) / COUNT(*), 2) AS open_ticket_rate,
       ROUND(MEDIAN(resolution_hours), 2) AS median_resolution_hours,
       ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction
FROM support_tickets
GROUP BY priority
ORDER BY ticket_count DESC;

-- 10. Monthly invoice trend
SELECT DATE_TRUNC('month', invoice_date) AS invoice_month,
       ROUND(SUM(amount), 2) AS invoiced_amount,
       ROUND(SUM(amount) FILTER (WHERE status = 'paid'), 2) AS paid_amount,
       ROUND(SUM(amount) FILTER (WHERE status <> 'paid'), 2) AS unpaid_amount,
       ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'paid') / COUNT(*), 2) AS collection_rate
FROM invoices
GROUP BY invoice_month
ORDER BY invoice_month;

-- 11. Underutilized active accounts
WITH user_counts AS (
    SELECT account_id, COUNT(*) AS users FROM users GROUP BY account_id
)
SELECT a.account_id, a.company_name, a.plan, s.seats,
       COALESCE(u.users, 0) AS users,
       s.seats - COALESCE(u.users, 0) AS unused_seats,
       ROUND(COALESCE(u.users, 0) * 1.0 / NULLIF(s.seats, 0), 4) AS seat_utilization
FROM accounts a
JOIN subscriptions s USING (account_id)
LEFT JOIN user_counts u USING (account_id)
WHERE s.status = 'active'
  AND COALESCE(u.users, 0) * 1.0 / NULLIF(s.seats, 0) < 0.50
ORDER BY unused_seats DESC, seat_utilization;

-- 12. Account support load
WITH user_counts AS (
    SELECT account_id, COUNT(*) AS users FROM users GROUP BY account_id
), ticket_counts AS (
    SELECT account_id, COUNT(*) AS tickets FROM support_tickets GROUP BY account_id
)
SELECT a.account_id, a.company_name,
       COALESCE(u.users, 0) AS users,
       COALESCE(t.tickets, 0) AS tickets,
       ROUND(100.0 * COALESCE(t.tickets, 0) / NULLIF(COALESCE(u.users, 0), 0), 2) AS tickets_per_100_users
FROM accounts a
LEFT JOIN user_counts u USING (account_id)
LEFT JOIN ticket_counts t USING (account_id)
ORDER BY tickets_per_100_users DESC NULLS LAST;

-- 13. Support load and churn
WITH user_counts AS (
    SELECT account_id, COUNT(*) AS users FROM users GROUP BY account_id
), ticket_counts AS (
    SELECT account_id, COUNT(*) AS tickets FROM support_tickets GROUP BY account_id
), account_load AS (
    SELECT a.account_id, s.status,
           100.0 * COALESCE(t.tickets, 0) / NULLIF(COALESCE(u.users, 0), 0) AS support_load
    FROM accounts a
    JOIN subscriptions s USING (account_id)
    LEFT JOIN user_counts u USING (account_id)
    LEFT JOIN ticket_counts t USING (account_id)
), quartiles AS (
    SELECT *, NTILE(4) OVER (ORDER BY support_load NULLS FIRST) AS support_quartile
    FROM account_load
)
SELECT support_quartile,
       COUNT(*) AS accounts,
       COUNT(*) FILTER (WHERE status = 'churned') AS churned_accounts,
       ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'churned') / COUNT(*), 2) AS churn_rate
FROM quartiles
GROUP BY support_quartile
ORDER BY support_quartile;

-- 14. Account health mart
WITH user_metrics AS (
    SELECT account_id, COUNT(*) AS users FROM users GROUP BY account_id
), invoice_metrics AS (
    SELECT account_id, COUNT(*) AS invoices,
           COUNT(*) FILTER (WHERE status = 'paid') AS paid_invoices,
           ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'paid') / COUNT(*), 2) AS invoice_collection_rate
    FROM invoices GROUP BY account_id
), ticket_metrics AS (
    SELECT account_id, COUNT(*) AS tickets,
           COUNT(*) FILTER (WHERE resolved_at IS NULL) AS open_tickets,
           ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction,
           ROUND(AVG(resolution_hours), 2) AS avg_resolution_hours
    FROM support_tickets GROUP BY account_id
)
SELECT a.account_id, a.company_name, a.industry, a.country, a.plan,
       s.status, s.mrr, s.seats,
       COALESCE(u.users, 0) AS users,
       ROUND(COALESCE(u.users, 0) * 1.0 / NULLIF(s.seats, 0), 4) AS seat_utilization,
       COALESCE(i.invoices, 0) AS invoices,
       COALESCE(i.invoice_collection_rate, 0) AS invoice_collection_rate,
       COALESCE(t.tickets, 0) AS tickets,
       COALESCE(t.open_tickets, 0) AS open_tickets,
       t.avg_satisfaction, t.avg_resolution_hours
FROM accounts a
JOIN subscriptions s USING (account_id)
LEFT JOIN user_metrics u USING (account_id)
LEFT JOIN invoice_metrics i USING (account_id)
LEFT JOIN ticket_metrics t USING (account_id);

-- 15. Signup cohort retention
SELECT DATE_TRUNC('quarter', a.signup_date) AS signup_quarter,
       COUNT(*) AS cohort_accounts,
       COUNT(*) FILTER (WHERE s.status = 'active') AS active_accounts,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'active') / COUNT(*), 2) AS snapshot_retention
FROM accounts a
JOIN subscriptions s USING (account_id)
GROUP BY signup_quarter
ORDER BY signup_quarter;

-- 16. Revenue concentration
WITH ranked AS (
    SELECT a.account_id, a.company_name, s.mrr,
           ROW_NUMBER() OVER (ORDER BY s.mrr DESC, a.account_id) AS revenue_rank,
           SUM(s.mrr) OVER (ORDER BY s.mrr DESC, a.account_id ROWS UNBOUNDED PRECEDING)
             / SUM(s.mrr) OVER () AS cumulative_mrr_share
    FROM accounts a JOIN subscriptions s USING (account_id)
    WHERE s.status = 'active'
)
SELECT *,
       CASE WHEN cumulative_mrr_share <= 0.50 THEN 'first 50%'
            WHEN cumulative_mrr_share <= 0.80 THEN 'next 30%'
            ELSE 'remaining 20%' END AS revenue_band
FROM ranked
ORDER BY revenue_rank;

-- 17. Plan performance ranking
WITH user_counts AS (
    SELECT account_id, COUNT(*) AS users FROM users GROUP BY account_id
), ticket_metrics AS (
    SELECT account_id, COUNT(*) AS tickets, AVG(satisfaction_score) AS satisfaction
    FROM support_tickets GROUP BY account_id
), account_metrics AS (
    SELECT a.plan, s.status, s.mrr,
           COALESCE(u.users, 0) * 1.0 / NULLIF(s.seats, 0) AS utilization,
           t.satisfaction,
           100.0 * COALESCE(t.tickets, 0) / NULLIF(COALESCE(u.users, 0), 0) AS support_load
    FROM accounts a JOIN subscriptions s USING (account_id)
    LEFT JOIN user_counts u USING (account_id)
    LEFT JOIN ticket_metrics t USING (account_id)
), plans AS (
    SELECT plan,
           SUM(mrr) FILTER (WHERE status = 'active') AS active_mrr,
           100.0 * COUNT(*) FILTER (WHERE status = 'churned') / COUNT(*) AS churn_rate,
           MEDIAN(utilization) AS median_utilization,
           AVG(satisfaction) AS avg_satisfaction,
           AVG(support_load) AS avg_support_load
    FROM account_metrics GROUP BY plan
)
SELECT *,
       RANK() OVER (ORDER BY active_mrr DESC) AS mrr_rank,
       RANK() OVER (ORDER BY churn_rate) AS churn_rank,
       RANK() OVER (ORDER BY median_utilization DESC) AS utilization_rank,
       RANK() OVER (ORDER BY avg_satisfaction DESC) AS satisfaction_rank,
       RANK() OVER (ORDER BY avg_support_load) AS support_load_rank
FROM plans
ORDER BY mrr_rank;

-- 18. Active versus churned accounts
WITH user_counts AS (
    SELECT account_id, COUNT(*) AS users FROM users GROUP BY account_id
), ticket_metrics AS (
    SELECT account_id, COUNT(*) AS tickets, AVG(satisfaction_score) AS satisfaction,
           AVG(resolution_hours) AS resolution_hours
    FROM support_tickets GROUP BY account_id
), invoice_metrics AS (
    SELECT account_id, 100.0 * COUNT(*) FILTER (WHERE status = 'paid') / COUNT(*) AS collection_rate
    FROM invoices GROUP BY account_id
)
SELECT s.status, COUNT(*) AS accounts,
       ROUND(AVG(a.employee_count), 2) AS avg_employees,
       ROUND(AVG(s.seats), 2) AS avg_seats,
       ROUND(AVG(COALESCE(u.users, 0)), 2) AS avg_users,
       ROUND(AVG(COALESCE(t.tickets, 0)), 2) AS avg_tickets,
       ROUND(AVG(t.satisfaction), 2) AS avg_satisfaction,
       ROUND(AVG(t.resolution_hours), 2) AS avg_resolution_hours,
       ROUND(AVG(i.collection_rate), 2) AS avg_collection_rate
FROM accounts a JOIN subscriptions s USING (account_id)
LEFT JOIN user_counts u USING (account_id)
LEFT JOIN ticket_metrics t USING (account_id)
LEFT JOIN invoice_metrics i USING (account_id)
WHERE s.status IN ('active', 'churned')
GROUP BY s.status;

-- 19. Invoice delinquency and churn
WITH delinquency AS (
    SELECT account_id,
           MAX(CASE WHEN status <> 'paid' THEN 1 ELSE 0 END) AS has_delinquency
    FROM invoices GROUP BY account_id
)
SELECT CASE WHEN d.has_delinquency = 1 THEN 'at least one non-paid invoice'
            ELSE 'all invoices paid' END AS invoice_group,
       COUNT(*) AS accounts,
       COUNT(*) FILTER (WHERE s.status = 'churned') AS churned_accounts,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'churned') / COUNT(*), 2) AS churn_rate
FROM subscriptions s
JOIN delinquency d USING (account_id)
GROUP BY d.has_delinquency
ORDER BY d.has_delinquency DESC;

-- 20. Executive SaaS scorecard
WITH subscription_kpis AS (
    SELECT COUNT(*) FILTER (WHERE status = 'active') AS active_customers,
           SUM(mrr) FILTER (WHERE status = 'active') AS active_mrr,
           100.0 * COUNT(*) FILTER (WHERE status = 'churned') / COUNT(*) AS logo_churn
    FROM subscriptions
), user_counts AS (
    SELECT account_id, COUNT(*) AS users FROM users GROUP BY account_id
), utilization AS (
    SELECT MEDIAN(COALESCE(u.users, 0) * 1.0 / NULLIF(s.seats, 0)) AS median_seat_utilization
    FROM subscriptions s LEFT JOIN user_counts u USING (account_id)
), invoice_kpis AS (
    SELECT 100.0 * COUNT(*) FILTER (WHERE status = 'paid') / COUNT(*) AS invoice_collection_rate
    FROM invoices
), ticket_kpis AS (
    SELECT 100.0 * COUNT(*) FILTER (WHERE resolved_at IS NULL) / COUNT(*) AS open_ticket_rate
    FROM support_tickets
)
SELECT active_customers,
       ROUND(active_mrr, 2) AS active_mrr,
       ROUND(active_mrr * 12, 2) AS arr_run_rate,
       ROUND(active_mrr / active_customers, 2) AS active_arpa,
       ROUND(logo_churn, 2) AS snapshot_logo_churn,
       ROUND(100.0 * median_seat_utilization, 2) AS median_seat_utilization,
       ROUND(invoice_collection_rate, 2) AS invoice_collection_rate,
       ROUND(open_ticket_rate, 2) AS open_ticket_rate
FROM subscription_kpis, utilization, invoice_kpis, ticket_kpis;

