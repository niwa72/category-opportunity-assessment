-- Stage 1: Build the Analytical Base Table
--
-- I joined order_items, orders, and products into a single table
-- so all three lenses (Demand, Continuation, Campaign) can work
-- from the same consistent grain without repeating joins.
--
-- Grain: one row per order item (order_item_id is unique, 480,481 rows).
-- I used LEFT JOIN rather than INNER JOIN to preserve all order items
-- even if a join partner is missing — data quality checks, not the
-- JOIN type, should be what surfaces problems.
--
-- item_status is kept unfiltered here. Filtering to 'Completed' only
-- happens inside each lens query. I validated this against the
-- shipments table: Completed items have 100% shipment coverage,
-- while Cancelled and Refunded both have 0%.

CREATE TABLE analysis_base AS
SELECT
    oi.order_item_id,
    oi.order_id,
    o.customer_id,
    o.order_date,
    oi.product_id,
    p.category,
    oi.line_total,
    oi.item_status,
    oi.is_campaign,
    oi.product_campaign_id
FROM shopee_order_items_thailand AS oi
LEFT JOIN shopee_orders_thailand      AS o  ON oi.order_id  = o.order_id
LEFT JOIN shopee_products_thailand    AS p  ON oi.product_id = p.product_id;
