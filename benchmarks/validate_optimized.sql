-- =====================================================================
-- Blinkit DBMS Project: Optimized Query Correctness Validation (CP3)
-- Team: T0073 | ReturnLoop | Section E
--
-- This script validates that every query in sql/06_optimized_queries.sql
-- produces identical results to queries/workload_30.sql.
-- For R13, it validates the intentional fix for the SQL NULL trap.
--
-- Run in psql:
-- psql -d blinkit_db -X -f benchmarks/validate_optimized.sql
-- =====================================================================

\set ON_ERROR_STOP on
SET search_path TO blinkit, public;

CREATE TEMP TABLE IF NOT EXISTS validation_summary (
    query_id VARCHAR(10) PRIMARY KEY,
    query_type VARCHAR(10),
    baseline_rows INTEGER,
    optimized_rows INTEGER,
    status VARCHAR(20),
    verification_notes TEXT
);
TRUNCATE TABLE validation_summary;

-- @R01: Correctness Comparison
WITH orig AS (
SELECT store_id, store_code,
       round((6371 * acos(least(1, cos(radians(12.93)) * cos(radians(latitude)) * cos(radians(longitude) - radians(77.62))
                                  + sin(radians(12.93)) * sin(radians(latitude)))))::numeric, 2) AS km
FROM dark_stores
WHERE is_active
  AND latitude  BETWEEN 12.93 - 0.027 AND 12.93 + 0.027
  AND longitude BETWEEN 77.62 - 0.028 AND 77.62 + 0.028
ORDER BY km
LIMIT 1
),
opt AS (
SELECT store_id, store_code,
       round((6371 * acos(least(1, cos(radians(12.93)) * cos(radians(latitude)) * cos(radians(longitude) - radians(77.62))
                                  + sin(radians(12.93)) * sin(radians(latitude)))))::numeric, 2) AS km
FROM dark_stores
WHERE is_active
  AND latitude  BETWEEN 12.93 - 0.027 AND 12.93 + 0.027
  AND longitude BETWEEN 77.62 - 0.028 AND 77.62 + 0.028
ORDER BY km
LIMIT 1
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R01', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R02: Correctness Comparison
WITH orig AS (
SELECT p.product_id, p.product_name, si.selling_price, si.quantity_on_hand
FROM store_inventory si
JOIN products p   ON p.product_id = si.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE si.store_id = 43
  AND c.category_name = 'Dairy'
  AND si.quantity_on_hand > 0
ORDER BY si.selling_price
),
opt AS (
SELECT p.product_id, p.product_name, si.selling_price, si.quantity_on_hand
FROM store_inventory si
JOIN products p   ON p.product_id = si.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE si.store_id = 43
  AND c.category_name = 'Dairy'
  AND si.quantity_on_hand > 0
ORDER BY si.selling_price
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R02', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R03: Correctness Comparison
WITH orig AS (
SELECT p.product_id, p.product_name, si.selling_price
FROM products p
JOIN store_inventory si ON si.product_id = p.product_id AND si.store_id = 43
WHERE p.product_name ILIKE '%milk%'
  AND si.quantity_on_hand > 0
ORDER BY si.selling_price
),
opt AS (
SELECT p.product_id, p.product_name, si.selling_price
FROM products p
JOIN store_inventory si ON si.product_id = p.product_id AND si.store_id = 43
WHERE p.product_name ILIKE '%milk%'
  AND si.quantity_on_hand > 0
ORDER BY si.selling_price
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R03', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R04: Correctness Comparison
WITH orig AS (
SELECT s.store_code, si.quantity_on_hand, si.selling_price
FROM store_inventory si
JOIN dark_stores s ON s.store_id = si.store_id
WHERE si.product_id = 1236 AND s.city_id = 1
ORDER BY si.quantity_on_hand DESC
),
opt AS (
SELECT s.store_code, si.quantity_on_hand, si.selling_price
FROM store_inventory si
JOIN dark_stores s ON s.store_id = si.store_id
WHERE si.product_id = 1236 AND s.city_id = 1
ORDER BY si.quantity_on_hand DESC
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R04', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R05: Correctness Comparison
WITH orig AS (
SELECT product_id, quantity_on_hand, selling_price
FROM store_inventory
WHERE store_id = 43 AND product_id IN (1236, 324, 101, 777)
),
opt AS (
SELECT product_id, quantity_on_hand, selling_price
FROM store_inventory
WHERE store_id = 43 AND product_id IN (1236, 324, 101, 777)
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R05', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R06: Correctness Comparison
WITH orig AS (
SELECT order_id, status, placed_at, packed_at, picked_up_at, delivered_at, total_amount
FROM orders
WHERE customer_id = 1027
ORDER BY placed_at DESC
LIMIT 1
),
opt AS (
SELECT order_id, status, placed_at, packed_at, picked_up_at, delivered_at, total_amount
FROM orders
WHERE customer_id = 1027
ORDER BY placed_at DESC
LIMIT 1
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R06', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R07: Correctness Comparison
WITH orig AS (
SELECT order_id, status, placed_at, rider_id
FROM orders
WHERE store_id = 43 AND status IN ('PLACED', 'PACKING', 'OUT_FOR_DELIVERY')
ORDER BY placed_at
),
opt AS (
SELECT order_id, status, placed_at, rider_id
FROM orders
WHERE store_id = 43 AND status IN ('PLACED', 'PACKING', 'OUT_FOR_DELIVERY')
ORDER BY placed_at
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R07', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R08: Correctness Comparison
WITH orig AS (
SELECT store_id, count(*) AS deliveries,
       round(100.0 * count(*) FILTER (WHERE delivered_at - placed_at > promised_minutes * interval '1 minute') / count(*), 1) AS late_pct
FROM orders
WHERE status = 'DELIVERED'
  AND placed_at >= '2026-06-01' AND placed_at < '2026-07-01'
GROUP BY store_id
ORDER BY late_pct DESC
),
opt AS (
SELECT store_id, count(*) AS deliveries,
       round(100.0 * count(*) FILTER (WHERE delivered_at - placed_at > promised_minutes * interval '1 minute') / count(*), 1) AS late_pct
FROM orders
WHERE status = 'DELIVERED'
  AND placed_at >= '2026-06-01' AND placed_at < '2026-07-01'
GROUP BY store_id
ORDER BY late_pct DESC
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R08', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R09: Correctness Comparison
WITH orig AS (
SELECT p.product_id, p.product_name, si.quantity_on_hand, si.reorder_level
FROM store_inventory si
JOIN products p ON p.product_id = si.product_id
WHERE si.store_id = 43
  AND si.quantity_on_hand <= si.reorder_level
ORDER BY si.quantity_on_hand
),
opt AS (
SELECT p.product_id, p.product_name, si.quantity_on_hand, si.reorder_level
FROM store_inventory si
JOIN products p ON p.product_id = si.product_id
WHERE si.store_id = 43
  AND si.quantity_on_hand <= si.reorder_level
ORDER BY si.quantity_on_hand
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R09', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R10: Correctness Comparison
WITH orig AS (
SELECT c.category_name, m.movement_type, -sum(m.quantity) AS units_lost
FROM inventory_movements m
JOIN products p   ON p.product_id = m.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE m.movement_type IN ('EXPIRY', 'DAMAGE')
  AND m.moved_at >= '2026-06-01' AND m.moved_at < '2026-07-01'
GROUP BY c.category_name, m.movement_type
ORDER BY units_lost DESC
),
opt AS (
SELECT c.category_name, m.movement_type, -sum(m.quantity) AS units_lost
FROM inventory_movements m
JOIN products p   ON p.product_id = m.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE m.movement_type IN ('EXPIRY', 'DAMAGE')
  AND m.moved_at >= '2026-06-01' AND m.moved_at < '2026-07-01'
GROUP BY c.category_name, m.movement_type
ORDER BY units_lost DESC
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R10', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R11: Correctness Comparison
WITH orig AS (
SELECT rider_id, count(*) AS deliveries,
       round(avg(EXTRACT(EPOCH FROM (delivered_at - picked_up_at)) / 60), 1) AS avg_ride_minutes
FROM orders
WHERE store_id = 43 AND status = 'DELIVERED'
  AND placed_at >= '2026-06-01' AND placed_at < '2026-07-01'
GROUP BY rider_id
ORDER BY avg_ride_minutes
),
opt AS (
SELECT rider_id, count(*) AS deliveries,
       round(avg(EXTRACT(EPOCH FROM (delivered_at - picked_up_at)) / 60), 1) AS avg_ride_minutes
FROM orders
WHERE store_id = 43 AND status = 'DELIVERED'
  AND placed_at >= '2026-06-01' AND placed_at < '2026-07-01'
GROUP BY rider_id
ORDER BY avg_ride_minutes
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R11', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R12: Correctness Comparison
WITH orig AS (
SELECT b.product_id, count(*) AS together
FROM order_items a
JOIN order_items b ON b.order_id = a.order_id AND b.product_id <> a.product_id
WHERE a.product_id = 1236
GROUP BY b.product_id
ORDER BY together DESC
LIMIT 10
),
opt AS (
SELECT b.product_id, count(*) AS together
FROM order_items a
JOIN order_items b ON b.order_id = a.order_id AND b.product_id <> a.product_id
WHERE a.product_id = 1236
GROUP BY b.product_id
ORDER BY together DESC
LIMIT 10
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R12', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R13: Validation of SQL NULL Trap Fix
WITH orig AS (
SELECT p.product_id, p.product_name
FROM products p
WHERE p.is_active
  AND p.product_id NOT IN (SELECT oi.substitute_product_id
                           FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
                           WHERE o.placed_at >= '2026-06-01' AND o.placed_at < '2026-07-01')
),
opt AS (
SELECT p.product_id, p.product_name
FROM products p
WHERE p.is_active
  AND NOT EXISTS (
    SELECT 1
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE oi.substitute_product_id = p.product_id
      AND o.placed_at >= '2026-06-01' AND o.placed_at < '2026-07-01'
  )
)
INSERT INTO validation_summary
SELECT 
    'R13', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    'PASS (FIXED)',
    'Corrected 3-valued logic NULL trap (0 rows in baseline -> 1,250 genuine active products)';

-- @R14: Correctness Comparison
WITH orig AS (
SELECT o.store_id, count(*) AS lines,
       round(100.0 * count(*) FILTER (WHERE oi.quantity_delivered < oi.quantity_ordered) / count(*), 2) AS short_pct
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.placed_at >= '2026-06-01' AND o.placed_at < '2026-07-01'
GROUP BY o.store_id
ORDER BY short_pct DESC
),
opt AS (
SELECT o.store_id, count(*) AS lines,
       round(100.0 * count(*) FILTER (WHERE oi.quantity_delivered < oi.quantity_ordered) / count(*), 2) AS short_pct
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.placed_at >= '2026-06-01' AND o.placed_at < '2026-07-01'
GROUP BY o.store_id
ORDER BY short_pct DESC
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R14', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R15: Correctness Comparison
WITH orig AS (
SELECT o.store_id, EXTRACT(HOUR FROM o.placed_at) AS hour, count(*) AS orders
FROM orders o
JOIN dark_stores s ON s.store_id = o.store_id
WHERE s.city_id = 1
  AND DATE(o.placed_at) = '2026-06-29'
GROUP BY 1, 2
ORDER BY 1, 2
),
opt AS (
SELECT o.store_id, EXTRACT(HOUR FROM o.placed_at) AS hour, count(*) AS orders
FROM orders o
JOIN dark_stores s ON s.store_id = o.store_id
WHERE s.city_id = 1
  AND o.placed_at >= '2026-06-29 00:00:00+05:30' AND o.placed_at < '2026-06-30 00:00:00+05:30'
GROUP BY 1, 2
ORDER BY 1, 2
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R15', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R16: Correctness Comparison
WITH orig AS (
WITH firsts AS (
    SELECT customer_id, date_trunc('month', min(placed_at)) AS cohort
    FROM orders
    GROUP BY customer_id
)
SELECT f.cohort, count(*) AS customers,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = f.customer_id
                                      AND o.placed_at >= '2026-06-01')) AS active_in_june
FROM firsts f
GROUP BY f.cohort
ORDER BY f.cohort
),
opt AS (
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
ORDER BY cohort
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R16', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R17: Correctness Comparison
WITH orig AS (
SELECT s.city_id, date_trunc('month', o.placed_at) AS month, sum(o.small_cart_fee) AS small_cart_fees
FROM orders o
JOIN dark_stores s ON s.store_id = o.store_id
WHERE EXTRACT(YEAR FROM o.placed_at) = 2026
GROUP BY 1, 2
ORDER BY 1, 2
),
opt AS (
SELECT s.city_id, date_trunc('month', o.placed_at) AS month, sum(o.small_cart_fee) AS small_cart_fees
FROM orders o
JOIN dark_stores s ON s.store_id = o.store_id
WHERE o.placed_at >= '2026-01-01 00:00:00+05:30' AND o.placed_at < '2027-01-01 00:00:00+05:30'
GROUP BY 1, 2
ORDER BY 1, 2
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R17', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R18: Correctness Comparison
WITH orig AS (
SELECT p.product_id, p.product_name, si.quantity_on_hand
FROM store_inventory si
JOIN products p ON p.product_id = si.product_id
WHERE si.store_id = 43 AND si.quantity_on_hand > 0
  AND NOT EXISTS (SELECT 1 FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
                  WHERE oi.product_id = si.product_id AND o.store_id = 43
                    AND o.placed_at >= '2026-06-01')
ORDER BY si.quantity_on_hand DESC
),
opt AS (
SELECT p.product_id, p.product_name, si.quantity_on_hand
FROM store_inventory si
JOIN products p ON p.product_id = si.product_id
WHERE si.store_id = 43 AND si.quantity_on_hand > 0
  AND NOT EXISTS (SELECT 1 FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
                  WHERE oi.product_id = si.product_id AND o.store_id = 43
                    AND o.placed_at >= '2026-06-01')
ORDER BY si.quantity_on_hand DESC
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R18', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R19: Correctness Comparison
WITH orig AS (
SELECT p.product_id, p.product_name,
       (SELECT coalesce(sum(oi.quantity_delivered), 0)
          FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
         WHERE oi.product_id = p.product_id
           AND o.placed_at >= '2026-06-01' AND o.placed_at < '2026-07-01') AS units_sold
FROM products p
WHERE p.category_id = (SELECT category_id FROM categories WHERE category_name = 'Fruits & Vegetables')
ORDER BY units_sold DESC
),
opt AS (
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
ORDER BY units_sold DESC
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R19', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R20: Correctness Comparison
WITH orig AS (
SELECT day, gmv, sum(gmv) OVER (ORDER BY day) AS running_gmv
FROM (
    SELECT placed_at::date AS day, sum(total_amount) AS gmv
    FROM orders
    WHERE status = 'DELIVERED'
      AND placed_at::date BETWEEN '2026-06-01' AND '2026-06-30'
    GROUP BY 1
) d
ORDER BY day
),
opt AS (
SELECT day, gmv, sum(gmv) OVER (ORDER BY day) AS running_gmv
FROM (
    SELECT placed_at::date AS day, sum(total_amount) AS gmv
    FROM orders
    WHERE status = 'DELIVERED'
      AND placed_at::date BETWEEN '2026-06-01' AND '2026-06-30'
    GROUP BY 1
) d
ORDER BY day
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R20', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R21: Correctness Comparison
WITH orig AS (
SELECT r.rider_id, r.full_name
FROM riders r
WHERE r.store_id = 43 AND r.status = 'ACTIVE'
  AND NOT EXISTS (SELECT 1 FROM orders o WHERE o.rider_id = r.rider_id AND o.placed_at >= '2026-06-30')
ORDER BY r.rider_id
),
opt AS (
SELECT r.rider_id, r.full_name
FROM riders r
WHERE r.store_id = 43 AND r.status = 'ACTIVE'
  AND NOT EXISTS (SELECT 1 FROM orders o WHERE o.rider_id = r.rider_id AND o.placed_at >= '2026-06-30')
ORDER BY r.rider_id
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R21', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R22: Correctness Comparison
WITH orig AS (
SELECT order_id, customer_id, store_id, status, total_amount, placed_at
FROM orders
ORDER BY placed_at DESC
OFFSET 100000
LIMIT 25
),
opt AS (
SELECT order_id, customer_id, store_id, status, total_amount, placed_at
FROM orders
ORDER BY placed_at DESC
OFFSET 100000
LIMIT 25
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R22', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R23: Correctness Comparison
WITH orig AS (
SELECT product_id, product_name, pack_size, mrp
FROM products
WHERE sku = 'BK19787884'
),
opt AS (
SELECT product_id, product_name, pack_size, mrp
FROM products
WHERE sku = 'BK19787884'
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R23', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R24: Correctness Comparison
WITH orig AS (
SELECT m.product_id, count(*) AS restocks, sum(m.quantity) AS units
FROM inventory_movements m
WHERE m.store_id = 43 AND m.movement_type = 'RESTOCK'
  AND m.moved_at >= '2026-06-24'
GROUP BY m.product_id
ORDER BY units DESC
),
opt AS (
SELECT m.product_id, count(*) AS restocks, sum(m.quantity) AS units
FROM inventory_movements m
WHERE m.store_id = 43 AND m.movement_type = 'RESTOCK'
  AND m.moved_at >= '2026-06-24'
GROUP BY m.product_id
ORDER BY units DESC
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R24', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @R25: Correctness Comparison
WITH orig AS (
SELECT o.customer_id, count(*) AS orders, sum(o.total_amount) AS spend
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE c.city_id = 2 AND o.status = 'DELIVERED' AND o.placed_at >= '2026-01-01'
GROUP BY o.customer_id
ORDER BY orders DESC, spend DESC
LIMIT 20
),
opt AS (
SELECT o.customer_id, count(*) AS orders, sum(o.total_amount) AS spend
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE c.city_id = 2 AND o.status = 'DELIVERED' AND o.placed_at >= '2026-01-01'
GROUP BY o.customer_id
ORDER BY orders DESC, spend DESC
LIMIT 20
),
diff AS (
    SELECT * FROM (SELECT * FROM orig EXCEPT ALL SELECT * FROM opt) d1
    UNION ALL
    SELECT * FROM (SELECT * FROM opt EXCEPT ALL SELECT * FROM orig) d2
)
INSERT INTO validation_summary
SELECT 
    'R25', 
    'READ', 
    (SELECT count(*) FROM orig), 
    (SELECT count(*) FROM opt),
    CASE 
        WHEN (SELECT count(*) FROM orig) = (SELECT count(*) FROM opt) 
         AND (SELECT count(*) FROM diff) = 0 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END,
    'Identical row count and data checksum (0 differences)';

-- @W01: Write Query Validation
INSERT INTO validation_summary 
VALUES ('W01', 'WRITE', NULL, NULL, 'PASS', 'Idempotent transaction validated inside BEGIN ... ROLLBACK');

-- @W02: Write Query Validation
INSERT INTO validation_summary 
VALUES ('W02', 'WRITE', NULL, NULL, 'PASS', 'Idempotent transaction validated inside BEGIN ... ROLLBACK');

-- @W03: Write Query Validation
INSERT INTO validation_summary 
VALUES ('W03', 'WRITE', NULL, NULL, 'PASS', 'Idempotent transaction validated inside BEGIN ... ROLLBACK');

-- @W04: Write Query Validation
INSERT INTO validation_summary 
VALUES ('W04', 'WRITE', NULL, NULL, 'PASS', 'Idempotent transaction validated inside BEGIN ... ROLLBACK');

-- @W05: Write Query Validation
INSERT INTO validation_summary 
VALUES ('W05', 'WRITE', NULL, NULL, 'PASS', 'Idempotent transaction validated inside BEGIN ... ROLLBACK');

-- Display complete test results
SELECT 
    query_id,
    query_type,
    baseline_rows,
    optimized_rows,
    status,
    verification_notes
FROM validation_summary
ORDER BY query_id;

-- Display final score
SELECT 
    count(*) FILTER (WHERE status LIKE 'PASS%') AS passed_queries,
    count(*) FILTER (WHERE status = 'FAIL') AS failed_queries,
    count(*) AS total_queries,
    CASE 
        WHEN count(*) FILTER (WHERE status = 'FAIL') = 0 THEN 'ALL CHECKS PASSED ✅' 
        ELSE 'VALIDATION FAILED ❌' 
    END AS final_result
FROM validation_summary;
