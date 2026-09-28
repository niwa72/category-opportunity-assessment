-- Stage 4: Campaign Association — 3-Point Sensitivity Range
--
-- I classified each order item into one of three states based on
-- the campaign fields available in the data:
--
--   campaign-associated    product_campaign_id IS NOT NULL (traceable to a named campaign)
--   campaign-untraceable   is_campaign = 1 but product_campaign_id IS NULL (has a discount,
--                          mean ~9.9%, but can't be linked to a specific campaign)
--   not campaign-associated  is_campaign = 0
--
-- I validated that there are zero cases where is_campaign = 0 and
-- product_campaign_id IS NOT NULL, so the classification has no
-- contradictions.
--
-- Because some campaign-flagged revenue can't be traced, I express
-- the result as a three-point range rather than a single number:
--
--   lower_bound_pct          only traceable campaign revenue in the numerator
--   identifiable_share_pct   excludes untraceable revenue from both numerator
--                            and denominator (treats it as unknown)
--   upper_bound_scenario_pct assumes all untraceable revenue was also campaign-driven
--
-- I call the metric "campaign-associated revenue share", not
-- "campaign dependency" — the data shows association, not causation.

WITH classified AS (
    SELECT
        category,
        item_status,
        line_total,
        CASE
            WHEN product_campaign_id IS NOT NULL THEN 'campaign-associated'
            WHEN is_campaign = 1                 THEN 'campaign-untraceable'
            ELSE                                      'not campaign-associated'
        END AS campaign_status
    FROM analysis_base
),
category_revenue AS (
    SELECT
        category,
        SUM(CASE WHEN item_status = 'Completed'
                 THEN line_total ELSE 0 END)                                 AS total_completed_revenue,
        SUM(CASE WHEN item_status = 'Completed'
                      AND campaign_status = 'campaign-associated'
                 THEN line_total ELSE 0 END)                                 AS campaign_revenue,
        SUM(CASE WHEN item_status = 'Completed'
                      AND campaign_status = 'campaign-untraceable'
                 THEN line_total ELSE 0 END)                                 AS untraceable_revenue
    FROM classified
    GROUP BY category
)
SELECT
    category,
    ROUND(campaign_revenue / total_completed_revenue * 100, 2)
        AS lower_bound_pct,
    ROUND(campaign_revenue / NULLIF(total_completed_revenue - untraceable_revenue, 0) * 100, 2)
        AS identifiable_share_pct,
    ROUND((campaign_revenue + untraceable_revenue) / total_completed_revenue * 100, 2)
        AS upper_bound_scenario_pct
FROM category_revenue
ORDER BY identifiable_share_pct ASC;
