-- =====================================================
-- Team T0073 | ReturnLoop | DE Checkpoint 1
-- Blinkit Grocery Delivery - CSV Data Loading
-- PostgreSQL 15
-- =====================================================

-- Run with psql from the repository root:
-- psql -X -v ON_ERROR_STOP=1 -d blinkit_db -f sql/02_load_data.sql
--
-- Before running:
-- 1. Execute sql/01_schema.sql.
-- 2. Extract seed_data.zip into a folder named seed_data
--    at the repository root.
-- 3. Run this script from the repository root.
--
-- NOTE: \copy is a psql meta-command, executed by the psql client.

\set ON_ERROR_STOP on

SET search_path TO blinkit, public;

-- Idempotency: Clean existing rows if reloading into an existing schema
TRUNCATE TABLE blinkit.inventory_movements,
               blinkit.order_items,
               blinkit.store_inventory,
               blinkit.orders,
               blinkit.riders,
               blinkit.customers,
               blinkit.products,
               blinkit.categories,
               blinkit.dark_stores,
               blinkit.cities CASCADE;

-- 1. Cities (independent parent table)
\copy blinkit.cities (city_id, city_name, state) FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 2. Dark Stores (depends on cities)
\copy blinkit.dark_stores (store_id, store_code, city_id, latitude, longitude, opened_on, is_active, max_daily_orders) FROM 'seed_data/dark_stores.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 3. Categories (independent parent table)
\copy blinkit.categories (category_id, category_name, is_perishable) FROM 'seed_data/categories.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 4. Products (depends on categories)
\copy blinkit.products (product_id, sku, product_name, brand, category_id, pack_size, mrp, shelf_life_days, is_active) FROM 'seed_data/products.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 5. Customers (depends on cities)
\copy blinkit.customers (customer_id, full_name, phone, email, city_id, created_at) FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 6. Riders (depends on dark stores)
\copy blinkit.riders (rider_id, full_name, phone, store_id, joined_on, status) FROM 'seed_data/riders.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 7. Orders (depends on customers, dark stores, riders)
\copy blinkit.orders (order_id, customer_id, store_id, rider_id, placed_at, packed_at, picked_up_at, delivered_at, promised_minutes, subtotal, delivery_fee, handling_fee, small_cart_fee, total_amount, payment_method, status) FROM 'seed_data/orders.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 8. Order Items (depends on orders and products)
\copy blinkit.order_items (order_id, product_id, quantity_ordered, quantity_delivered, unit_price, substitute_product_id) FROM 'seed_data/order_items.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 9. Store Inventory (depends on dark stores and products)
\copy blinkit.store_inventory (store_id, product_id, quantity_on_hand, reorder_level, selling_price, updated_at) FROM 'seed_data/store_inventory.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 10. Inventory Movements (depends on store_inventory)
\copy blinkit.inventory_movements (movement_id, store_id, product_id, movement_type, quantity, moved_at) FROM 'seed_data/inventory_movements.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- =====================================================
-- Update PostgreSQL optimizer statistics
-- =====================================================

ANALYZE blinkit.cities;
ANALYZE blinkit.dark_stores;
ANALYZE blinkit.categories;
ANALYZE blinkit.products;
ANALYZE blinkit.customers;
ANALYZE blinkit.riders;
ANALYZE blinkit.orders;
ANALYZE blinkit.order_items;
ANALYZE blinkit.store_inventory;
ANALYZE blinkit.inventory_movements;

-- =====================================================
-- Verify row counts against seed_data specification
-- =====================================================

SELECT 'cities' AS table_name, COUNT(*) AS loaded_count, 10 AS expected_count FROM blinkit.cities
UNION ALL
SELECT 'dark_stores', COUNT(*), 120 FROM blinkit.dark_stores
UNION ALL
SELECT 'categories', COUNT(*), 12 FROM blinkit.categories
UNION ALL
SELECT 'products', COUNT(*), 1500 FROM blinkit.products
UNION ALL
SELECT 'customers', COUNT(*), 40000 FROM blinkit.customers
UNION ALL
SELECT 'riders', COUNT(*), 1800 FROM blinkit.riders
UNION ALL
SELECT 'orders', COUNT(*), 150000 FROM blinkit.orders
UNION ALL
SELECT 'order_items', COUNT(*), 675000 FROM blinkit.order_items
UNION ALL
SELECT 'store_inventory', COUNT(*), 126000 FROM blinkit.store_inventory
UNION ALL
SELECT 'inventory_movements', COUNT(*), 90000 FROM blinkit.inventory_movements;

-- =====================================================
-- Integrity checks
-- Each check must return 0 violations.
-- =====================================================

-- 1. Referential integrity: Orders referencing missing customers
SELECT COUNT(*) AS invalid_customer_references
FROM blinkit.orders o
LEFT JOIN blinkit.customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 2. Referential integrity: Order items referencing missing products
SELECT COUNT(*) AS invalid_product_references
FROM blinkit.order_items oi
LEFT JOIN blinkit.products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- 3. Business rule: Every ordered product is stocked by the fulfilling dark store
SELECT COUNT(*) AS unstocked_order_items
FROM blinkit.order_items oi
JOIN blinkit.orders o ON o.order_id = oi.order_id
LEFT JOIN blinkit.store_inventory si
    ON si.store_id = o.store_id AND si.product_id = oi.product_id
WHERE si.product_id IS NULL;

-- 4. Business rule: Assigned riders deliver only orders from their own dark store
SELECT COUNT(*) AS rider_store_mismatches
FROM blinkit.orders o
JOIN blinkit.riders r ON r.rider_id = o.rider_id
WHERE o.rider_id IS NOT NULL
  AND o.store_id <> r.store_id;

-- 5. Business rule: Any substitute product is also stocked by the fulfilling dark store
SELECT COUNT(*) AS unstocked_substitutes
FROM blinkit.order_items oi
JOIN blinkit.orders o ON o.order_id = oi.order_id
LEFT JOIN blinkit.store_inventory si
    ON si.store_id = o.store_id AND si.product_id = oi.substitute_product_id
WHERE oi.substitute_product_id IS NOT NULL
  AND si.product_id IS NULL;

-- 6. Financial integrity: Order subtotal equals sum of delivered items * unit price
SELECT COUNT(*) AS subtotal_mismatches
FROM (
    SELECT o.order_id, o.subtotal,
           ROUND(SUM(oi.quantity_delivered * oi.unit_price), 2) AS calc_subtotal
    FROM blinkit.orders o
    JOIN blinkit.order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'DELIVERED'
    GROUP BY o.order_id, o.subtotal
    HAVING o.subtotal <> ROUND(SUM(oi.quantity_delivered * oi.unit_price), 2)
) sub;

-- 7. Operational rule: All orders were placed at active dark stores
SELECT COUNT(*) AS orders_at_inactive_stores
FROM blinkit.orders o
JOIN blinkit.dark_stores ds ON ds.store_id = o.store_id
WHERE NOT ds.is_active;

-- 8. Quantity rule: Quantity delivered must not exceed quantity ordered
SELECT COUNT(*) AS overdelivered_items
FROM blinkit.order_items
WHERE quantity_delivered > quantity_ordered;

-- 9. Inventory rule: No negative stock in dark store inventory
SELECT COUNT(*) AS negative_inventory_records
FROM blinkit.store_inventory
WHERE quantity_on_hand < 0;

-- =====================================================
-- End of data loading script
-- =====================================================
