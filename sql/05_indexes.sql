-- =====================================================================
-- Blinkit DBMS Project: Performance Optimization Indexes (CP3 / Phase 4)
-- Team: T0073 | ReturnLoop | Section E
--
-- This script provisions targeted secondary, composite, partial, covering,
-- and expression/GIN indexes to optimize the 30 workload queries based on
-- query execution plans observed in CP2 baseline benchmarks.
--
-- DESIGN PRINCIPLES:
-- 1. Equality columns first, then range/sorting columns (B-tree ordering).
-- 2. Partial indexes on filtered subsets (e.g. pending order statuses) to
--    minimize index footprint and avoid write amplification.
-- 3. Covering indexes (INCLUDE) for Index Only Scans on heavy joins.
-- 4. Avoid redundant indexes on columns already covered by existing primary
--    key or unique constraint indexes.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS blinkit;
SET search_path TO blinkit, public;

-- Enable trigram extension for substring ILIKE pattern matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ---------------------------------------------------------------------
-- 1. ORDERS TABLE INDEXES
-- ---------------------------------------------------------------------

-- Query: R06 (Order tracking), R16 (Cohorts), R25 (Customer loyalty)
-- Rationale: In CP2, R06 suffered a 13.2 ms sequential scan over all 150,000 orders.
-- Filtering by customer_id followed by descending sort on placed_at allows
-- a single-leaf Index Scan that fetches the latest customer order in < 0.1 ms.
CREATE INDEX IF NOT EXISTS idx_orders_customer_placed
    ON orders(customer_id, placed_at DESC);

-- Query: R07 (Open orders screen), R11 (Rider delivery SLA), R18 (Dead stock), W02 (Packing deduction)
-- Rationale: Eliminates sequential scans on orders for dark-store operations.
-- Equality on store_id, filtering on status, and ordering by placed_at.
CREATE INDEX IF NOT EXISTS idx_orders_store_status_placed
    ON orders(store_id, status, placed_at);

-- Query: R08 (SLA report), R14 (Fill rate), R15 (Staffing), R17 (Small cart fees),
--        R19 (Category report), R20 (GMV), R22 (Deep pagination)
-- Rationale: Accelerates time-range slicing across June 2026 and removes the
-- in-memory sorting bottleneck in R22 (ORDER BY placed_at DESC OFFSET 100000 LIMIT 25).
CREATE INDEX IF NOT EXISTS idx_orders_placed_at
    ON orders(placed_at DESC);

-- Query: R21 (Active riders with no deliveries), R11 (Rider deliveries)
-- Rationale: Partial index on orders that have an assigned rider, enabling
-- fast NOT EXISTS anti-join checks on delivery activity without indexing unassigned orders.
CREATE INDEX IF NOT EXISTS idx_orders_rider_placed
    ON orders(rider_id, placed_at)
    WHERE rider_id IS NOT NULL;

-- Query: W02 (Recent placed/packing order), W03 (Dispatch oldest packing order)
-- Rationale: Partial index exclusively covering the small active working set of
-- unfulfilled orders (status IN ('PLACED', 'PACKING')). This allows subqueries to
-- find min/max order_id via direct Index Only Scans in < 0.3 ms while adding near-zero
-- write overhead to delivered orders.
CREATE INDEX IF NOT EXISTS idx_orders_status_pending
    ON orders(status, order_id)
    WHERE status IN ('PLACED', 'PACKING');


-- ---------------------------------------------------------------------
-- 2. ORDER_ITEMS TABLE INDEXES
-- ---------------------------------------------------------------------

-- Query: R12 (Co-purchased recommendations), R13 (Category substitutes),
--        R18 (Dead stock sales check), R19 (Fruits & Vegetables category sales)
-- Rationale: The primary key is (order_id, product_id). Queries filtering or joining
-- on product_id alone cannot utilize the PK index and were forced into a full 675,000-row
-- sequential scan. This index reverses the leading column to product_id and includes
-- delivered/ordered quantities and substitute IDs to support Index Only Scans.
CREATE INDEX IF NOT EXISTS idx_order_items_product_order
    ON order_items(product_id, order_id)
    INCLUDE (quantity_delivered, quantity_ordered, substitute_product_id);


-- ---------------------------------------------------------------------
-- 3. INVENTORY_MOVEMENTS TABLE INDEXES
-- ---------------------------------------------------------------------

-- Query: R24 (Supply chain restock reporting for store 43)
-- Rationale: Multi-column B-tree matching equality on store_id and movement_type = 'RESTOCK',
-- then range scan on moved_at for the trailing 7 days.
CREATE INDEX IF NOT EXISTS idx_inventory_movements_store_type_date
    ON inventory_movements(store_id, movement_type, moved_at);

-- Query: R10 (Wastage units lost to damage/expiry), W05 (Data retention purge)
-- Rationale: B-tree on moved_at date range with movement_type to accelerate monthly
-- wastage aggregations and historical data retention deletions.
CREATE INDEX IF NOT EXISTS idx_inventory_movements_moved_at_type
    ON inventory_movements(moved_at, movement_type);


-- ---------------------------------------------------------------------
-- 4. PRODUCTS & CATEGORIES TABLE INDEXES
-- ---------------------------------------------------------------------

-- Query: R02 (Category product listing), R10 (Wastage by category), R19 (Category report)
-- Rationale: PostgreSQL does not automatically index foreign key columns. Indexing
-- category_id on products accelerates relational joins from categories into products.
CREATE INDEX IF NOT EXISTS idx_products_category_id
    ON products(category_id);

-- Query: R03 (Search products with 'milk')
-- Rationale: Standard B-tree indexes cannot index leading wildcards ('%milk%').
-- A GIN trigram index on product_name allows PostgreSQL to accelerate ILIKE '%...%'
-- patterns through trigram signature matching.
CREATE INDEX IF NOT EXISTS idx_products_name_trgm
    ON products USING gin (product_name gin_trgm_ops);


-- ---------------------------------------------------------------------
-- 5. CUSTOMERS & RIDERS TABLE INDEXES
-- ---------------------------------------------------------------------

-- Query: R25 (Mumbai customer loyalty report)
-- Rationale: Accelerates filtering the 40,000-row customer base by operating city_id = 2.
CREATE INDEX IF NOT EXISTS idx_customers_city_id
    ON customers(city_id);

-- Query: R21 (Active riders at store 43), W03 (Rider assignment)
-- Rationale: Composite B-tree for fast lookup of active delivery riders assigned to a store.
CREATE INDEX IF NOT EXISTS idx_riders_store_status
    ON riders(store_id, status);

-- Update statistics for the PostgreSQL query planner
ANALYZE;
