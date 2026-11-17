# Baseline Query Timings Report – Blinkit Grocery Delivery

**Team:** T0073 – ReturnLoop  
**Section:** E  
**Database:** PostgreSQL 15  
**Schema Name:** `blinkit`  
**Checkpoint:** DE Checkpoint 2 (CP2)  
**Hardware / Environment:** MacBook Pro (Apple Silicon), PostgreSQL 15, Default configuration (`work_mem = 4MB`, `shared_buffers = 128MB`)  
**Benchmark Date:** November 17, 2026  

---

## 1. Executive Summary

This report documents the baseline performance benchmark of the **30 standard production queries** (`R01`–`R25` read queries and `W01`–`W05` write queries) executed against the PostgreSQL database for Blinkit's 10-minute grocery delivery platform.

In strict adherence to the project specification for Phase 3 (CP2):
1. The database is in an un-tuned baseline state containing **only primary key and unique constraints** automatically created by PostgreSQL. No secondary indexes, covering indexes, partial indexes, or performance tunings have been introduced.
2. Every query was measured using `EXPLAIN (ANALYZE, BUFFERS)` over **three consecutive runs**, and the arithmetic average of execution times was computed.
3. All write queries (`W01`–`W05`) were executed inside transactional wrappers (`BEGIN; ... ROLLBACK;`) to ensure underlying dataset idempotency and zero state corruption across runs.
4. Total execution time for all 30 baseline queries is **2,372.682 ms** (~2.37 seconds), with individual query latencies ranging from **0.023 ms** (single-row unique B-tree index lookup) to **2,059.691 ms** (unindexed nested loop and sequential scans across 675,000 order items).

---

## 2. Baseline Benchmark Timing Table

The table below reports execution times across Run 1, Run 2, Run 3, and the computed Average for all 30 queries.

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Store assignment: the nearest active dark store within ~3 km of a customer at (12.93, 77.62) | READ | 0.560 | 0.124 | 0.252 | 0.312 |
| R02: Category page: Dairy products in stock at store 43, cheapest first | READ | 1.351 | 0.623 | 1.182 | 1.052 |
| R03: Search: products with "milk" in the name that are in stock at store 43 | READ | 0.886 | 2.287 | 1.948 | 1.707 |
| R04: Product page: stock of product 1236 in every Bengaluru dark store | READ | 0.341 | 0.331 | 0.328 | 0.333 |
| R05: Cart check: current stock and price of 4 cart items at store 43 | READ | 0.143 | 0.082 | 0.116 | 0.114 |
| R06: Order tracking: customer 1027's latest order with its timeline | READ | 19.573 | 10.832 | 9.210 | 13.205 |
| R07: Store screen: open orders at store 43 (not yet delivered or cancelled) | READ | 8.997 | 9.711 | 10.060 | 9.589 |
| R08: SLA report: share of June 2026 deliveries that took longer than promised, per store | READ | 9.074 | 9.753 | 13.681 | 10.836 |
| R09: Replenishment: products at store 43 at or below their reorder level | READ | 0.229 | 0.781 | 0.805 | 0.605 |
| R10: Wastage: units lost to expiry or damage per category in June 2026 | READ | 14.544 | 10.308 | 7.608 | 10.820 |
| R11: Rider performance: average minutes from pickup to delivery per rider at store 43 (June 2026) | READ | 9.873 | 9.096 | 8.988 | 9.319 |
| R12: Recommendations: products most often bought together with product 1236 | READ | 12.129 | 12.659 | 12.016 | 12.268 |
| R13: Category team: active products that were never given as a substitute in June 2026 | READ | 26.856 | 23.250 | 21.702 | 23.936 |
| R14: Fill rate: share of order lines delivered short, per store, June 2026 | READ | 20.233 | 19.697 | 19.701 | 19.877 |
| R15: Staffing: orders per hour at Bengaluru stores on 29 June 2026 | READ | 9.090 | 9.286 | 9.170 | 9.182 |
| R16: Growth: monthly cohorts—customers by month of first order, and how many ordered again in June 2026 | READ | 36.163 | 33.234 | 33.973 | 34.457 |
| R17: Finance: small-cart fee collected per city per month in 2026 | READ | 32.586 | 30.490 | 35.913 | 32.996 |
| R18: Dead stock: products in stock at store 43 that did not sell there in June 2026 | READ | 5.019 | 7.529 | 5.407 | 5.985 |
| R19: Category report: June 2026 units sold of every Fruits & Vegetables product | READ | 2148.610 | 2017.322 | 2013.142 | 2059.691 |
| R20: Finance: daily GMV and running total for June 2026 | READ | 9.405 | 9.316 | 9.339 | 9.353 |
| R21: Store manager: active riders of store 43 with no delivery on 30 June 2026 | READ | 5.581 | 5.772 | 6.520 | 5.958 |
| R22: Support console: all orders, newest first, page 4,001 (25 per page) | READ | 36.185 | 33.822 | 33.799 | 34.602 |
| R23: Warehouse scanner: look up a product by SKU | READ | 0.025 | 0.021 | 0.023 | 0.023 |
| R24: Supply chain: units restocked per product at store 43 in the last 7 days of June 2026 | READ | 3.419 | 3.552 | 3.995 | 3.655 |
| R25: Loyalty: 20 Mumbai customers with the most delivered orders in 2026 | READ | 19.266 | 17.056 | 16.320 | 17.547 |
| W01: Checkout: place a new order at store 43 | WRITE | 0.461 | 0.492 | 0.421 | 0.458 |
| W02: Packing done: reduce store 43's stock for every line of its most recent PLACED or PACKING order | WRITE | 14.482 | 14.545 | 13.299 | 14.109 |
| W03: Dispatch: give the oldest PACKING order (anywhere) to its store's first active rider | WRITE | 13.378 | 13.180 | 12.863 | 13.140 |
| W04: Nightly replenishment at store 43: top up everything at or below reorder level | WRITE | 0.841 | 0.641 | 0.487 | 0.656 |
| W05: Data retention: delete inventory movements older than 1 January 2026 | WRITE | 11.877 | 21.282 | 17.527 | 16.895 |
| **Total (sum of all 30)** | | **2471.177** | **2327.074** | **2319.795** | **2372.682** |

---

## 3. Query Plan Analysis & Performance Root Causes

This section details the scan types observed in the query execution plans (`EXPLAIN (ANALYZE, BUFFERS)`) and provides the technical rationale for why each query is fast or slow.

### R01: Store Assignment
- **Scan Type:** `Seq Scan on dark_stores`
- **Execution Time (Avg):** 0.312 ms
- **Technical Explanation:** Fast because the `dark_stores` table is very compact (120 rows across 2 disk pages), allowing a sequential scan and Haversine bounding-box evaluation to complete in under 0.4 ms in-memory.

### R02: Category Page (Dairy at Store 43)
- **Scan Type:** `Seq Scan on products` | `Seq Scan on categories` | `Index Scan using pk_store_inventory on store_inventory`
- **Execution Time (Avg):** 1.052 ms
- **Technical Explanation:** Fast because `categories` (12 rows) and `products` (1,500 rows) are small and cached in shared buffers, while inventory lookups utilize the composite primary key index (`pk_store_inventory` on `store_id, product_id`).

### R03: Search (Products with "milk" at Store 43)
- **Scan Type:** `Seq Scan on products` | `Index Scan using pk_store_inventory on store_inventory`
- **Execution Time (Avg):** 1.707 ms
- **Technical Explanation:** Fast due to the small size of `products` (1,500 rows) allowing a quick sequential scan with substring pattern matching (`ILIKE '%milk%'`), followed by indexed lookups into `store_inventory`.

### R04: Product Page (Product 1236 in Bengaluru)
- **Scan Type:** `Seq Scan on dark_stores` | `Index Scan using pk_store_inventory on store_inventory`
- **Execution Time (Avg):** 0.333 ms
- **Technical Explanation:** Fast because the planner scans the 120-row `dark_stores` table filtered by `city_id = 1` and joins into `store_inventory` via the primary key index.

### R05: Cart Check (Stock/Price for 4 Items at Store 43)
- **Scan Type:** `Index Scan using pk_store_inventory on store_inventory`
- **Execution Time (Avg):** 0.114 ms
- **Technical Explanation:** Extremely fast because the query performs a direct multi-key B-tree index lookup on `(store_id, product_id)` using the primary key index, avoiding any sequential table scan.

### R06: Order Tracking (Customer 1027 Timeline)
- **Scan Type:** `Seq Scan on orders`
- **Execution Time (Avg):** 13.205 ms
- **Technical Explanation:** Slow because `orders` lacks an index on `customer_id` or `(customer_id, placed_at DESC)`, forcing PostgreSQL to perform a full sequential scan of all 150,000 orders and an in-memory Sort to find the latest order.

### R07: Store Screen (Open Orders at Store 43)
- **Scan Type:** `Parallel Seq Scan on orders`
- **Execution Time (Avg):** 9.589 ms
- **Technical Explanation:** Slow because without an index on `(store_id, status)` or a partial index on open orders, PostgreSQL must launch parallel workers to scan all 150,000 rows in `orders`.

### R08: SLA Report (Late Deliveries per Store in June 2026)
- **Scan Type:** `Parallel Seq Scan on orders`
- **Execution Time (Avg):** 10.836 ms
- **Technical Explanation:** Moderately slow because filtering for June 2026 deliveries across all stores requires scanning 150,000 order records in parallel to compute delivery duration vs promised minutes.

### R09: Replenishment (Low Stock at Store 43)
- **Scan Type:** `Seq Scan on products` | `Bitmap Heap Scan on store_inventory` | `Bitmap Index Scan on pk_store_inventory`
- **Execution Time (Avg):** 0.605 ms
- **Technical Explanation:** Fast because the planner uses a Bitmap Index Scan on `pk_store_inventory` matching the leading key `store_id = 43`, retrieving relevant inventory rows quickly and joining with the small `products` table.

### R10: Wastage (Damage/Expiry per Category in June 2026)
- **Scan Type:** `Seq Scan on inventory_movements` | `Seq Scan on products` | `Index Scan using categories_pkey on categories`
- **Execution Time (Avg):** 10.820 ms
- **Technical Explanation:** Moderately slow because there is no index on `inventory_movements(moved_at, movement_type)`, requiring a sequential scan over 90,000 inventory movement rows.

### R11: Rider Performance (Pickup to Delivery at Store 43)
- **Scan Type:** `Parallel Seq Scan on orders`
- **Execution Time (Avg):** 9.319 ms
- **Technical Explanation:** Slow because `orders` lacks an index on `(store_id, status, placed_at)`, requiring parallel workers to scan all 150,000 orders to calculate time deltas for store 43's June deliveries.

### R12: Recommendations (Co-Purchased with Product 1236)
- **Scan Type:** `Parallel Seq Scan on order_items` | `Index Only Scan using pk_order_items on order_items`
- **Execution Time (Avg):** 12.268 ms
- **Technical Explanation:** Slow because finding orders containing product 1236 requires scanning all 675,000 rows in `order_items` before performing self-joins to aggregate co-purchased items.

### R13: Category Team (Active Products Never Substituted)
- **Scan Type:** `Seq Scan on products` | `Parallel Seq Scan on order_items` | `Parallel Seq Scan on orders`
- **Execution Time (Avg):** 23.936 ms
- **Technical Explanation:** Slow due to the anti-join (`NOT IN` / `NOT EXISTS`) requiring full sequential scans over both `orders` (150,000 rows) and `order_items` (675,000 rows) to filter non-null substitute product IDs in June 2026.

### R14: Fill Rate (Short Deliveries per Store in June 2026)
- **Scan Type:** `Parallel Seq Scan on order_items` | `Parallel Seq Scan on orders`
- **Execution Time (Avg):** 19.877 ms
- **Technical Explanation:** Slow because calculating store-level short deliveries requires a large hash join between two full-table sequential scans: 150,000 rows of `orders` and 675,000 rows of `order_items`.

### R15: Staffing (Hourly Orders in Bengaluru on 29 June 2026)
- **Scan Type:** `Seq Scan on orders` | `Index Scan using dark_stores_pkey on dark_stores`
- **Execution Time (Avg):** 9.182 ms
- **Technical Explanation:** Moderately slow because date filtering on `placed_at` must scan all 150,000 rows in `orders` before joining store keys against `dark_stores`.

### R16: Growth (Customer First-Order Cohorts & Retention)
- **Scan Type:** `Seq Scan on orders`
- **Execution Time (Avg):** 34.457 ms
- **Technical Explanation:** Slow because evaluating customer cohort creation and June 2026 re-orders requires reading all 150,000 rows of `orders`, performing full-table customer-level aggregations, and sorting cohort groups.

### R17: Finance (Small-Cart Fees per City per Month)
- **Scan Type:** `Seq Scan on orders` | `Index Scan using dark_stores_pkey on dark_stores`
- **Execution Time (Avg):** 32.996 ms
- **Technical Explanation:** Slow because grouping and aggregating small-cart fees across the entire year 2026 requires sequentially scanning all 150,000 orders and hashing monthly dates by city.

### R18: Dead Stock (Stocked at Store 43 but Not Sold in June 2026)
- **Scan Type:** `Parallel Seq Scan on orders` | `Index Only Scan using pk_order_items on order_items` | `Bitmap Heap Scan on store_inventory` | `Bitmap Index Scan on pk_store_inventory` | `Seq Scan on products`
- **Execution Time (Avg):** 5.985 ms
- **Technical Explanation:** Moderate latency due to scanning June 2026 orders at store 43 and anti-joining against store inventory via bitmap scans on the composite primary key index.

### R19: Category Report (June 2026 Fruits & Vegetables Sales)
- **Scan Type:** `Seq Scan on categories` | `Seq Scan on products` | `Seq Scan on order_items` | `Index Scan using orders_pkey on orders`
- **Execution Time (Avg):** 2059.691 ms
- **Technical Explanation:** **Extreme bottleneck.** This query accounts for ~87% of the total workload benchmark runtime. The query engine performs a nested loop join across 675,000 `order_items` rows filtered by product categories, repeatedly executing primary key index lookups on `orders` to check `placed_at` timestamps without a date index or foreign key index on `order_items(product_id)`.

### R20: Finance (Daily GMV and Running Cumulative Total)
- **Scan Type:** `Parallel Seq Scan on orders`
- **Execution Time (Avg):** 9.353 ms
- **Technical Explanation:** Moderately slow because filtering for delivered orders in June 2026 requires sequentially reading the entire 150,000-row `orders` table before applying window aggregate functions.

### R21: Store Manager (Active Riders with No Delivery on 30 June)
- **Scan Type:** `Seq Scan on orders` | `Seq Scan on riders`
- **Execution Time (Avg):** 5.958 ms
- **Technical Explanation:** Moderate latency because finding unassigned riders on a specific date performs an anti-join (`NOT EXISTS`) between all active riders at store 43 and the day's delivery records.

### R22: Support Console (All Orders Deep Pagination Page 4,001)
- **Scan Type:** `Seq Scan on orders`
- **Execution Time (Avg):** 34.602 ms
- **Technical Explanation:** High latency due to classical `OFFSET` pagination overhead: PostgreSQL must sort and scan 100,025 rows (`OFFSET 100000 LIMIT 25`) from `orders` without an index on `placed_at DESC`.

### R23: Warehouse Scanner (Product Lookup by SKU)
- **Scan Type:** `Index Scan using products_sku_key on products`
- **Execution Time (Avg):** 0.023 ms
- **Technical Explanation:** The fastest query in the entire workload (< 0.03 ms), executing a direct single-leaf B-tree index lookup using the unique constraint index on `products(sku)`.

### R24: Supply Chain (Restock Units at Store 43 in Last 7 Days)
- **Scan Type:** `Seq Scan on inventory_movements`
- **Execution Time (Avg):** 3.655 ms
- **Technical Explanation:** Moderate latency because filtering restock movements at store 43 over a 7-day window must sequentially scan all 90,000 rows in `inventory_movements`.

### R25: Loyalty (Top 20 Mumbai Customers by Orders in 2026)
- **Scan Type:** `Seq Scan on orders` | `Seq Scan on customers`
- **Execution Time (Avg):** 17.547 ms
- **Technical Explanation:** Slow because joining orders with Mumbai customers (`city_id = 2`) requires scanning 150,000 order records and 40,000 customer records followed by a large hash aggregation and Top-N sort.

### W01: Checkout (New Order Insert at Store 43)
- **Scan Type:** `(no scan)`
- **Execution Time (Avg):** 0.458 ms
- **Technical Explanation:** Fast single-row insert into `orders` requiring minimal page allocation and only updating the single primary key index `orders_pkey`.

### W02: Packing Done (Stock Deduction for Latest Placed/Packing Order)
- **Scan Type:** `Seq Scan on orders` | `Index Scan using pk_order_items on order_items` | `Index Scan using pk_store_inventory on store_inventory`
- **Execution Time (Avg):** 14.109 ms
- **Technical Explanation:** High write latency caused by the correlated subquery scanning all 150,000 orders to locate `max(order_id)` for store 43 in status `PLACED`/`PACKING` before updating `store_inventory`.

### W03: Dispatch (Assign Oldest Packing Order to First Active Rider)
- **Scan Type:** `Index Scan using orders_pkey on orders` | `Index Scan using riders_pkey on riders`
- **Execution Time (Avg):** 13.140 ms
- **Technical Explanation:** High write latency due to subqueries scanning `orders` for status `'PACKING'` and searching `riders` for active personnel before updating order timestamps and status.

### W04: Nightly Replenishment (Top Up Low Stock at Store 43)
- **Scan Type:** `Bitmap Heap Scan on store_inventory` | `Bitmap Index Scan on pk_store_inventory`
- **Execution Time (Avg):** 0.656 ms
- **Technical Explanation:** Fast batch update because `store_id = 43` is indexed via `pk_store_inventory`, allowing PostgreSQL to efficiently identify and update only the low-stock inventory records.

### W05: Data Retention (Purge Inventory Movements Older Than 2026)
- **Scan Type:** `Seq Scan on inventory_movements`
- **Execution Time (Avg):** 16.895 ms
- **Technical Explanation:** High write latency because locating records with `moved_at < '2026-01-01'` requires a full sequential scan of all 90,000 rows in `inventory_movements` without a date index.

---

## 4. Latency Distribution & Bottleneck Categorization

The baseline workload demonstrates clear performance clustering based on index availability and table scan sizes:

| Latency Tier | Queries | Characteristics |
|---|---|---|
| **Sub-millisecond (< 1 ms)** | R01, R04, R05, R09, R23, W01, W04 (7 queries) | Point lookups on primary keys (`pk_store_inventory`, `products_sku_key`) or small in-memory tables (`dark_stores`, 120 rows). |
| **Low Latency (1 – 5 ms)** | R02, R03, R24 (3 queries) | Small table joins (`products`, `categories`) or partial indexed lookups. |
| **Moderate Latency (5 – 15 ms)** | R06, R07, R08, R10, R11, R12, R15, R18, R20, R21, W02, W03 (12 queries) | Single-table sequential scans across `orders` (150k rows) or `inventory_movements` (90k rows). |
| **High Latency (15 – 40 ms)** | R13, R14, R16, R17, R22, R25, W05 (7 queries) | Multi-table joins (orders + order_items), analytical aggregations, deep offset pagination, or whole-table anti-joins. |
| **Critical Bottleneck (> 2000 ms)** | R19 (1 query) | Unindexed join across 675k order items and 150k orders with nested-loop row evaluations. |

---

## 5. Architectural Findings & Roadmap for Phase 4 (CP3 Optimization)

1. **Missing Foreign Key Indexes:**
   - In PostgreSQL, foreign keys do NOT automatically create secondary indexes. Consequently, joins on `orders(customer_id)`, `orders(store_id)`, `order_items(product_id)`, and `inventory_movements(store_id)` result in repeated full-table sequential scans.
2. **Date Range & Filter Attributes:**
   - Queries frequently filter on `orders(placed_at)`, `orders(status)`, and `inventory_movements(moved_at)`. Composite B-tree indexes such as `(store_id, status, placed_at)` and `(moved_at, movement_type)` will dramatically reduce scan volume.
3. **Deep Pagination Offset:**
   - Query `R22` suffers from `OFFSET 100000`. Implementing index-backed ordering or keyset pagination will eliminate scanning the prior 100,000 rows.
4. **Subquery Inefficiencies in Writes:**
   - `W02` and `W03` spend over 13 ms each on subqueries scanning for order statuses. Targeted partial indexes (e.g. `WHERE status IN ('PLACED', 'PACKING')`) will reduce write transaction latency to sub-millisecond territory.
5. **The R19 Critical Bottleneck:**
   - `R19` requires targeted indexing on `orders(placed_at)` and `order_items(product_id)`, or join reordering to prevent repeated nested-loop scans.
