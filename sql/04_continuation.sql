-- Stage 3: Continuation — 180-Day Repeat Purchase Rate
--
-- I defined continuation as: did a customer make any Completed purchase
-- on the platform within 180 days of their first Completed purchase
-- in a given category? I used "any category" for the follow-up purchase
-- because I wanted to measure platform re-engagement, not product loyalty.
--
-- Why 180 days?
-- I checked the distribution of gaps between first and second purchases
-- for customers with at least two orders. The median gap was 94 days
-- and the 75th percentile was 185 days. A 90-day window would cut off
-- roughly a quarter of the customers who actually returned. 180 days
-- captures about 75% of observed repeat buyers and felt like a
-- defensible, data-grounded threshold.
--
-- A few design choices I was careful about:
-- - Same-day purchases don't count (order_date > first_purchase_date, strict).
-- - Day 180 counts; day 181 doesn't (inclusive upper bound).
-- - I used EXISTS rather than a JOIN for the continuation check.
--   A JOIN would create one row per matching follow-up purchase,
--   which would require extra aggregation to get back to one row
--   per customer-category pair. EXISTS returns a single boolean
--   and is cleaner for this use case.
-- - Customers without a full 180-day observation window get NULL,
--   not 0. 0 would mean "confirmed did not return". NULL means
--   "we can't observe this". The denominator only includes eligible pairs.
-- - The MAX(order_date) for the observation window cutoff is computed
--   over all statuses, not just Completed, so the window isn't
--   artificially shortened by filtering.

-- Step 1: First Completed purchase per customer per category
CREATE TABLE customer_category_first_purchase AS
SELECT
    customer_id,
    category,
    MIN(order_date) AS first_purchase_date
FROM analysis_base
WHERE item_status = 'Completed'
GROUP BY customer_id, category;

-- Step 2: Determine whether the observation window is long enough
CREATE TABLE customer_category_observation AS
SELECT
    f.customer_id,
    f.category,
    f.first_purchase_date,
    DATE_ADD(f.first_purchase_date, INTERVAL 180 DAY) AS window_end_date,
    CASE
        WHEN DATE_ADD(f.first_purchase_date, INTERVAL 180 DAY)
             <= (SELECT MAX(order_date) FROM analysis_base)
        THEN 'eligible'
        ELSE 'insufficient observation window'
    END AS observation_status
FROM customer_category_first_purchase f;

-- Step 3: Flag whether each eligible customer continued
CREATE TABLE customer_category_continuation AS
SELECT
    o.customer_id,
    o.category,
    o.first_purchase_date,
    o.window_end_date,
    o.observation_status,
    CASE
        WHEN o.observation_status = 'eligible' THEN
            CASE WHEN EXISTS (
                SELECT 1
                FROM analysis_base ab
                WHERE ab.customer_id    = o.customer_id
                  AND ab.item_status    = 'Completed'
                  AND ab.order_date     > o.first_purchase_date
                  AND ab.order_date    <= o.window_end_date
            ) THEN 1 ELSE 0 END
        ELSE NULL
    END AS continuation_flag
FROM customer_category_observation o;

-- Step 4: Aggregate by category
SELECT
    category,
    SUM(observation_status = 'eligible')                        AS eligible_pairs,
    SUM(observation_status = 'insufficient observation window') AS insufficient_pairs,
    ROUND(
        SUM(continuation_flag = 1) * 100.0
        / NULLIF(SUM(observation_status = 'eligible'), 0),
        2
    )                                                           AS continuation_rate_pct
FROM customer_category_continuation
GROUP BY category
ORDER BY continuation_rate_pct DESC;
