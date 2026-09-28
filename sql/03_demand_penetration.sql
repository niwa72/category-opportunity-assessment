-- Stage 2b: Demand — Annual Penetration Rate
--
-- The platform's active customer base grew roughly 6.6x between 2022
-- and 2025. If I had used absolute customer growth, every category
-- would show strong growth simply because the platform grew — which
-- would tell me nothing about which categories are actually gaining
-- or losing ground relative to each other.
--
-- Penetration rate (category customers ÷ total active customers that year)
-- controls for that platform-wide effect. A category rising in penetration
-- is genuinely expanding its share of platform buyers.
--
-- A few things I was careful about:
-- - Both numerator and denominator use Completed-only customers.
--   Mixing statuses would distort the rate.
-- - Penetration across categories won't sum to 100% because customers
--   can buy from multiple categories. I call it "category penetration
--   among active customers", not market share.
-- - LAG() computes the year-on-year change in percentage points (pp),
--   not a growth rate — the math is different and pp is the right unit here.

WITH yearly_category_customers AS (
    SELECT
        category,
        YEAR(order_date)            AS yr,
        COUNT(DISTINCT customer_id) AS category_customers
    FROM analysis_base
    WHERE item_status = 'Completed'
    GROUP BY category, YEAR(order_date)
),
yearly_active_customers AS (
    SELECT
        YEAR(order_date)            AS yr,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM analysis_base
    WHERE item_status = 'Completed'
    GROUP BY YEAR(order_date)
),
penetration AS (
    SELECT
        c.category,
        c.yr,
        c.category_customers,
        a.active_customers,
        c.category_customers / a.active_customers AS penetration
    FROM yearly_category_customers c
    JOIN yearly_active_customers a ON c.yr = a.yr
)
SELECT
    category,
    yr,
    category_customers,
    active_customers,
    ROUND(penetration * 100, 2)                                                                AS penetration_pct,
    ROUND(LAG(penetration) OVER (PARTITION BY category ORDER BY yr) * 100, 2)                 AS prior_penetration_pct,
    ROUND((penetration - LAG(penetration) OVER (PARTITION BY category ORDER BY yr)) * 100, 2) AS penetration_change_pp
FROM penetration
ORDER BY category, yr;
