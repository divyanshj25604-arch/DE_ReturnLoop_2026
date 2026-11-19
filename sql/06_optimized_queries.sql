-- =====================================================================
-- Blinkit DBMS Project: Optimized Workload Queries (CP3 / Phase 4)
-- Team: T0073 | ReturnLoop | Section E
--
-- This file contains the 30 workload queries for Phase 4 benchmarking.
-- Queries rewritten for performance or logical correctness:
--   - R13: Rewritten with NOT EXISTS to fix the classic SQL 3-valued logic
--          NULL trap (original returned 0 rows because substitute_product_id has NULLs).
--   - R15: Rewritten with sargable date range instead of DATE(o.placed_at).
--   - R16: Rewritten into a single-pass aggregation to avoid correlated subqueries.
--   - R17: Rewritten with sargable year range instead of EXTRACT(YEAR FROM o.placed_at).
--   - R19: Rewritten from a correlated subquery into a LEFT JOIN with GROUP BY,
--          eliminating the massive nested-loop bottleneck.
--
-- All other queries remain structurally identical to queries/workload_30.sql
-- while taking full advantage of the performance indexes in sql/05_indexes.sql.
-- =====================================================================

SET search_path TO blinkit, public;
BEGIN;

-- @R01
-- Store assignment: the nearest active dark store within ~3 km of a customer at (12.93, 77.62)
SELECT store_id, store_code,
       round((6371 * acos(least(1, cos(radians(12.93)) * cos(radians(latitude)) * cos(radians(longitude) - radians(77.62))
                                  + sin(radians(12.93)) * sin(radians(latitude)))))::numeric, 2) AS km
FROM dark_stores
WHERE is_active
  AND latitude  BETWEEN 12.93 - 0.027 AND 12.93 + 0.027
  AND longitude BETWEEN 77.62 - 0.028 AND 77.62 + 0.028
ORDER BY km
LIMIT 1;

-- @R02
-- Category page: Dairy products in stock at store 43, cheapest first
SELECT p.product_id, p.product_name, si.selling_price, si.quantity_on_hand
FROM store_inventory si
JOIN products p   ON p.product_id = si.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE si.store_id = 43
  AND c.category_name = 'Dairy'
  AND si.quantity_on_hand > 0
ORDER BY si.selling_price;

-- @R03
-- Search: products with "milk" in the name that are in stock at store 43
SELECT p.product_id, p.product_name, si.selling_price
FROM products p
JOIN store_inventory si ON si.product_id = p.product_id AND si.store_id = 43
WHERE p.product_name ILIKE '%milk%'
  AND si.quantity_on_hand > 0
ORDER BY si.selling_price;

-- @R04
-- Product page: stock of product 1236 in every Bengaluru dark store
SELECT s.store_code, si.quantity_on_hand, si.selling_price
FROM store_inventory si
JOIN dark_stores s ON s.store_id = si.store_id
WHERE si.product_id = 1236 AND s.city_id = 1
ORDER BY si.quantity_on_hand DESC;

-- @R05
-- Cart check: current stock and price of 4 cart items at store 43
SELECT product_id, quantity_on_hand, selling_price
FROM store_inventory
WHERE store_id = 43 AND product_id IN (1236, 324, 101, 777);

-- @R06
-- Order tracking: customer 1027's latest order with its timeline
SELECT order_id, status, placed_at, packed_at, picked_up_at, delivered_at, total_amount
FROM orders
WHERE customer_id = 1027
ORDER BY placed_at DESC
LIMIT 1;

-- @R07
-- Store screen: open orders at store 43 (not yet delivered or cancelled)
SELECT order_id, status, placed_at, rider_id
FROM orders
WHERE store_id = 43 AND status IN ('PLACED', 'PACKING', 'OUT_FOR_DELIVERY')
ORDER BY placed_at;

-- @R08
-- SLA report: share of June 2026 deliveries that took longer than promised, per store
SELECT store_id, count(*) AS deliveries,
       round(100.0 * count(*) FILTER (WHERE delivered_at - placed_at > promised_minutes * interval '1 minute') / count(*), 1) AS late_pct
FROM orders
WHERE status = 'DELIVERED'
  AND placed_at >= '2026-06-01' AND placed_at < '2026-07-01'
GROUP BY store_id
ORDER BY late_pct DESC;

-- @R09
-- Replenishment: products at store 43 at or below their reorder level
SELECT p.product_id, p.product_name, si.quantity_on_hand, si.reorder_level
FROM store_inventory si
JOIN products p ON p.product_id = si.product_id
WHERE si.store_id = 43
  AND si.quantity_on_hand <= si.reorder_level
ORDER BY si.quantity_on_hand;

-- @R10
-- Wastage: units lost to expiry or damage per category in June 2026
SELECT c.category_name, m.movement_type, -sum(m.quantity) AS units_lost
FROM inventory_movements m
JOIN products p   ON p.product_id = m.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE m.movement_type IN ('EXPIRY', 'DAMAGE')
  AND m.moved_at >= '2026-06-01' AND m.moved_at < '2026-07-01'
GROUP BY c.category_name, m.movement_type
ORDER BY units_lost DESC;

-- @R11
-- Rider performance: average minutes from pickup to delivery per rider at store 43 (June 2026)
SELECT rider_id, count(*) AS deliveries,
       round(avg(EXTRACT(EPOCH FROM (delivered_at - picked_up_at)) / 60), 1) AS avg_ride_minutes
FROM orders
WHERE store_id = 43 AND status = 'DELIVERED'
  AND placed_at >= '2026-06-01' AND placed_at < '2026-07-01'
GROUP BY rider_id
ORDER BY avg_ride_minutes;

-- @R12
-- Recommendations: products most often bought together with product 1236
SELECT b.product_id, count(*) AS together
FROM order_items a
JOIN order_items b ON b.order_id = a.order_id AND b.product_id <> a.product_id
WHERE a.product_id = 1236
GROUP BY b.product_id
ORDER BY together DESC
LIMIT 10;

-- @R13
-- Category team: active products that were never given as a substitute in June 2026
-- Optimized & Corrected: uses NOT EXISTS to avoid the SQL 3-valued logic NULL trap
-- where NULL substitute_product_id caused NOT IN to evaluate to UNKNOWN and return 0 rows.
SELECT p.product_id, p.product_name
FROM products p
WHERE p.is_active
  AND NOT EXISTS (
    SELECT 1
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE oi.substitute_product_id = p.product_id
      AND o.placed_at >= '2026-06-01' AND o.placed_at < '2026-07-01'
  );

-- @R14
-- Fill rate: share of order lines delivered short, per store, June 2026
SELECT o.store_id, count(*) AS lines,
       round(100.0 * count(*) FILTER (WHERE oi.quantity_delivered < oi.quantity_ordered) / count(*), 2) AS short_pct
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.placed_at >= '2026-06-01' AND o.placed_at < '2026-07-01'
GROUP BY o.store_id
ORDER BY short_pct DESC;

-- @R15
-- Staffing: orders per hour at Bengaluru stores on 29 June 2026
-- Optimized: rewritten with sargable date range on placed_at to use B-tree index
SELECT o.store_id, EXTRACT(HOUR FROM o.placed_at) AS hour, count(*) AS orders
FROM orders o
JOIN dark_stores s ON s.store_id = o.store_id
WHERE s.city_id = 1
  AND o.placed_at >= '2026-06-29 00:00:00+05:30' AND o.placed_at < '2026-06-30 00:00:00+05:30'
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R16
-- Growth: monthly cohorts—customers by month of first order, and how many ordered again in June 2026
-- Optimized: rewritten as a single-pass aggregation to compute cohort and active status simultaneously
WITH customer_stats AS (
    SELECT customer_id,
           date_trunc('month', min(placed_at)) AS cohort,
           bool_or(placed_at >= '2026-06-01') AS active_in_june
    FROM orders
    GROUP BY customer_id
)
SELECT cohort,
       count(*) AS customers,
       count(*) FILTER (WHERE active_in_june) AS active_in_june
FROM customer_stats
GROUP BY cohort
ORDER BY cohort;

-- @R17
-- Finance: small-cart fee collected per city per month in 2026
-- Optimized: rewritten with sargable year range on placed_at to leverage idx_orders_placed_at
SELECT s.city_id, date_trunc('month', o.placed_at) AS month, sum(o.small_cart_fee) AS small_cart_fees
FROM orders o
JOIN dark_stores s ON s.store_id = o.store_id
WHERE o.placed_at >= '2026-01-01 00:00:00+05:30' AND o.placed_at < '2027-01-01 00:00:00+05:30'
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R18
-- Dead stock: products in stock at store 43 that did not sell there in June 2026
SELECT p.product_id, p.product_name, si.quantity_on_hand
FROM store_inventory si
JOIN products p ON p.product_id = si.product_id
WHERE si.store_id = 43 AND si.quantity_on_hand > 0
  AND NOT EXISTS (SELECT 1 FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
                  WHERE oi.product_id = si.product_id AND o.store_id = 43
                    AND o.placed_at >= '2026-06-01')
ORDER BY si.quantity_on_hand DESC;

-- @R19
-- Category report: June 2026 units sold of every Fruits & Vegetables product
-- Optimized: rewritten from correlated subquery per product to a single LEFT JOIN with GROUP BY
SELECT p.product_id, p.product_name,
       coalesce(sum(oi.quantity_delivered), 0) AS units_sold
FROM products p
JOIN categories c ON c.category_id = p.category_id AND c.category_name = 'Fruits & Vegetables'
LEFT JOIN (
    order_items oi
    JOIN orders o ON o.order_id = oi.order_id
                 AND o.placed_at >= '2026-06-01' AND o.placed_at < '2026-07-01'
) ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY units_sold DESC;

-- @R20
-- Finance: daily GMV and running total for June 2026
SELECT day, gmv, sum(gmv) OVER (ORDER BY day) AS running_gmv
FROM (
    SELECT placed_at::date AS day, sum(total_amount) AS gmv
    FROM orders
    WHERE status = 'DELIVERED'
      AND placed_at::date BETWEEN '2026-06-01' AND '2026-06-30'
    GROUP BY 1
) d
ORDER BY day;

-- @R21
-- Store manager: active riders of store 43 with no delivery on 30 June 2026
SELECT r.rider_id, r.full_name
FROM riders r
WHERE r.store_id = 43 AND r.status = 'ACTIVE'
  AND NOT EXISTS (SELECT 1 FROM orders o WHERE o.rider_id = r.rider_id AND o.placed_at >= '2026-06-30')
ORDER BY r.rider_id;

-- @R22
-- Support console: all orders, newest first, page 4,001 (25 per page)
SELECT order_id, customer_id, store_id, status, total_amount, placed_at
FROM orders
ORDER BY placed_at DESC
OFFSET 100000
LIMIT 25;

-- @R23
-- Warehouse scanner: look up a product by SKU
SELECT product_id, product_name, pack_size, mrp
FROM products
WHERE sku = 'BK19787884';

-- @R24
-- Supply chain: units restocked per product at store 43 in the last 7 days of June 2026
SELECT m.product_id, count(*) AS restocks, sum(m.quantity) AS units
FROM inventory_movements m
WHERE m.store_id = 43 AND m.movement_type = 'RESTOCK'
  AND m.moved_at >= '2026-06-24'
GROUP BY m.product_id
ORDER BY units DESC;

-- @R25
-- Loyalty: 20 Mumbai customers with the most delivered orders in 2026
SELECT o.customer_id, count(*) AS orders, sum(o.total_amount) AS spend
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE c.city_id = 2 AND o.status = 'DELIVERED' AND o.placed_at >= '2026-01-01'
GROUP BY o.customer_id
ORDER BY orders DESC, spend DESC
LIMIT 20;

-- @W01
-- Checkout: place a new order at store 43
INSERT INTO orders (order_id, customer_id, store_id, placed_at, subtotal, delivery_fee, handling_fee, small_cart_fee,
                    total_amount, payment_method, status)
VALUES (90000001, 1027, 43, '2026-07-01 08:00:00+05:30', 245.00, 0, 6, 0, 251.00, 'UPI', 'PLACED');

-- @W02
-- Packing done: reduce store 43's stock for every line of its most recent PLACED or PACKING order
UPDATE store_inventory si
SET quantity_on_hand = greatest(0, si.quantity_on_hand - oi.quantity_ordered),
    updated_at = '2026-07-01 08:05:00+05:30'
FROM order_items oi
WHERE oi.order_id = (SELECT max(order_id) FROM orders WHERE store_id = 43 AND status IN ('PLACED', 'PACKING'))
  AND si.store_id = 43
  AND si.product_id = oi.product_id;

-- @W03
-- Dispatch: give the oldest PACKING order (anywhere) to its store's first active rider
UPDATE orders o
SET rider_id = (SELECT min(r.rider_id) FROM riders r WHERE r.store_id = o.store_id AND r.status = 'ACTIVE'),
    status = 'OUT_FOR_DELIVERY',
    picked_up_at = coalesce(o.packed_at, o.placed_at) + interval '1 minute',
    packed_at = coalesce(o.packed_at, o.placed_at + interval '30 seconds')
WHERE o.order_id = (SELECT min(order_id) FROM orders WHERE status = 'PACKING');

-- @W04
-- Nightly replenishment at store 43: top up everything at or below reorder level
UPDATE store_inventory
SET quantity_on_hand = reorder_level * 4, updated_at = '2026-07-01 05:00:00+05:30'
WHERE store_id = 43 AND quantity_on_hand <= reorder_level;

-- @W05
-- Data retention: delete inventory movements older than 1 January 2026
DELETE FROM inventory_movements
WHERE moved_at < '2026-01-01';

-- @END
ROLLBACK;
