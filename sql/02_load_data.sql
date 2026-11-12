
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
-- NOTE: \copy is a psql command, not standard SQL.

\set ON_ERROR_STOP on

SET search_path TO blinkit, public;

-- 1. Cities (parent table)
\copy blinkit.cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 2. Dark Stores (depends on cities)
\copy blinkit.dark_stores FROM 'seed_data/dark_stores.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 3. Categories (parent table)
\copy blinkit.categories FROM 'seed_data/categories.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 4. Products (depends on categories)
\copy blinkit.products FROM 'seed_data/products.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 5. Customers (depends on cities)
\copy blinkit.customers FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 6. Riders (depends on dark stores)
\copy blinkit.riders FROM 'seed_data/riders.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 7. Orders (depends on customers, stores, riders)
\copy blinkit.orders FROM 'seed_data/orders.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 8. Order Items (depends on orders and products)
\copy blinkit.order_items FROM 'seed_data/order_items.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 9. Store Inventory (depends on stores and products)
\copy blinkit.store_inventory FROM 'seed_data/store_inventory.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- 10. Inventory Movements
\copy blinkit.inventory_movements FROM 'seed_data/inventory_movements.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- =====================================================
-- Update PostgreSQL statistics
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
-- Verify row counts
-- =====================================================

SELECT 'cities' AS table_name, COUNT(*) AS row_count
FROM blinkit.cities
UNION ALL
SELECT 'dark_stores', COUNT(*) FROM blinkit.dark_stores
UNION ALL
SELECT 'categories', COUNT(*) FROM blinkit.categories
UNION ALL
SELECT 'products', COUNT(*) FROM blinkit.products
UNION ALL
SELECT 'customers', COUNT(*) FROM blinkit.customers
UNION ALL
SELECT 'riders', COUNT(*) FROM blinkit.riders
UNION ALL
SELECT 'orders', COUNT(*) FROM blinkit.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM blinkit.order_items
UNION ALL
SELECT 'store_inventory', COUNT(*) FROM blinkit.store_inventory
UNION ALL
SELECT 'inventory_movements', COUNT(*)
FROM blinkit.inventory_movements;

-- =====================================================
-- Integrity checks
-- Each query should return zero.
-- =====================================================

-- Orders referencing missing customers
SELECT COUNT(*) AS invalid_customer_references
FROM blinkit.orders o
LEFT JOIN blinkit.customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order items referencing missing products
SELECT COUNT(*) AS invalid_product_references
FROM blinkit.order_items oi
LEFT JOIN blinkit.products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Inventory rows referencing missing stores
SELECT COUNT(*) AS invalid_store_references
FROM blinkit.store_inventory si
LEFT JOIN blinkit.dark_stores ds
    ON si.store_id = ds.store_id
WHERE ds.store_id IS NULL;

-- Negative inventory quantities
SELECT COUNT(*) AS negative_inventory_records
FROM blinkit.store_inventory
WHERE quantity_on_hand < 0;

-- =====================================================
-- End of data loading script
-- =====================================================
