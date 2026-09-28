-- Stage 2a: Demand — Category Scale
--
-- I measured demand using unique customers per category, not order
-- count or revenue directly. One order can span multiple categories,
-- so order count would double-count. Revenue alone would favour
-- high-price categories like Electronics over Groceries regardless
-- of actual customer reach, which isn't what I wanted to compare.
--
-- Revenue and revenue per customer are included as supporting metrics
-- to show the commercial value behind each category's customer base.
-- I labelled revenue per customer as a transaction-value metric,
-- not as profitability or LTV — the dataset doesn't support those.

SELECT
    category,
    COUNT(DISTINCT customer_id)                                         AS unique_customers,
    SUM(line_total)                                                     AS revenue,
    ROUND(SUM(line_total) / COUNT(DISTINCT customer_id), 0)            AS revenue_per_customer
FROM analysis_base
WHERE item_status = 'Completed'
GROUP BY category
ORDER BY unique_customers DESC;
