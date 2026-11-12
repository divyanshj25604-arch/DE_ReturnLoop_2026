# Database Schema Design – Blinkit Grocery Delivery

**Team:** T0073 – ReturnLoop  
**Section:** E  
**Database:** PostgreSQL 15  
**Schema Name:** `blinkit`

## 1. Introduction

This document describes the relational database schema for the Blinkit Grocery Delivery dataset. The database manages cities, dark stores, product categories, products, customers, delivery riders, orders, order items, store inventory, and inventory movements.

The schema is designed to maintain data integrity, minimize redundancy, and support efficient SQL queries for business analytics.

## 2. Database Tables

The database consists of 10 relational tables.

### 2.1 Cities

| Column | Data Type | Constraints |
|---|---|---|
| city_id | INTEGER | PRIMARY KEY |
| city_name | VARCHAR(100) | NOT NULL |
| state | VARCHAR(100) | NOT NULL |

**Purpose:** Stores information about cities where Blinkit operates.

### 2.2 Dark Stores

| Column | Data Type | Constraints |
|---|---|---|
| store_id | INTEGER | PRIMARY KEY |
| store_code | VARCHAR(30) | NOT NULL, UNIQUE |
| city_id | INTEGER | NOT NULL, FOREIGN KEY |
| latitude | NUMERIC(10,7) | CHECK (-90 to 90) |
| longitude | NUMERIC(10,7) | CHECK (-180 to 180) |
| opened_on | DATE | |
| is_active | BOOLEAN | NOT NULL |
| max_daily_orders | INTEGER | CHECK (greater than 0) |

**Foreign Key:** `city_id` references `cities(city_id)`.

**Purpose:** Stores information about dark stores, their locations, and their daily order capacity.

### 2.3 Categories

| Column | Data Type | Constraints |
|---|---|---|
| category_id | INTEGER | PRIMARY KEY |
| category_name | VARCHAR(100) | NOT NULL, UNIQUE |
| is_perishable | BOOLEAN | NOT NULL |

**Purpose:** Classifies products into categories such as dairy, beverages, snacks, and household items.

### 2.4 Products

| Column | Data Type | Constraints |
|---|---|---|
| product_id | INTEGER | PRIMARY KEY |
| sku | VARCHAR(30) | NOT NULL, UNIQUE |
| product_name | VARCHAR(255) | NOT NULL |
| brand | VARCHAR(100) | |
| category_id | INTEGER | NOT NULL, FOREIGN KEY |
| pack_size | VARCHAR(50) | |
| mrp | NUMERIC(10,2) | CHECK (greater than 0) |
| shelf_life_days | INTEGER | NULL allowed, CHECK (greater than 0) |
| is_active | BOOLEAN | NOT NULL |

**Foreign Key:** `category_id` references `categories(category_id)`.

**Purpose:** Stores product details, prices, packaging information, and shelf life.

### 2.5 Customers

| Column | Data Type | Constraints |
|---|---|---|
| customer_id | INTEGER | PRIMARY KEY |
| full_name | VARCHAR(150) | NOT NULL |
| phone | VARCHAR(20) | NOT NULL, UNIQUE |
| email | VARCHAR(255) | NULL allowed |
| city_id | INTEGER | NOT NULL, FOREIGN KEY |
| created_at | TIMESTAMPTZ | NOT NULL |

**Foreign Key:** `city_id` references `cities(city_id)`.

**Purpose:** Stores customer information and registration details.

### 2.6 Riders

| Column | Data Type | Constraints |
|---|---|---|
| rider_id | INTEGER | PRIMARY KEY |
| full_name | VARCHAR(150) | NOT NULL |
| phone | VARCHAR(20) | NOT NULL, UNIQUE |
| store_id | INTEGER | NOT NULL, FOREIGN KEY |
| joined_on | DATE | NOT NULL |
| status | VARCHAR(20) | CHECK (ACTIVE, ON_LEAVE, EXITED) |

**Foreign Key:** `store_id` references `dark_stores(store_id)`.

**Purpose:** Stores delivery rider details and their assigned dark stores.

### 2.7 Orders

| Column | Data Type | Constraints |
|---|---|---|
| order_id | INTEGER | PRIMARY KEY |
| customer_id | INTEGER | NOT NULL, FOREIGN KEY |
| store_id | INTEGER | NOT NULL, FOREIGN KEY |
| rider_id | INTEGER | NULL allowed, FOREIGN KEY |
| placed_at | TIMESTAMPTZ | NOT NULL |
| packed_at | TIMESTAMPTZ | NULL allowed |
| picked_up_at | TIMESTAMPTZ | NULL allowed |
| delivered_at | TIMESTAMPTZ | NULL allowed |
| promised_minutes | INTEGER | CHECK (greater than 0) |
| subtotal | NUMERIC(10,2) | CHECK (at least 0) |
| delivery_fee | NUMERIC(10,2) | CHECK (at least 0) |
| handling_fee | NUMERIC(10,2) | CHECK (at least 0) |
| small_cart_fee | NUMERIC(10,2) | CHECK (at least 0) |
| total_amount | NUMERIC(10,2) | CHECK (at least 0) |
| payment_method | VARCHAR(20) | CHECK (UPI, COD, WALLET, CARD) |
| status | VARCHAR(30) | CHECK (DELIVERED, CANCELLED, PACKING, OUT_FOR_DELIVERY, PLACED) |

**Foreign Keys:**
- `customer_id` references `customers(customer_id)`.
- `store_id` references `dark_stores(store_id)`.
- `rider_id` references `riders(rider_id)`.

**Purpose:** Stores order transactions, payments, delivery timestamps, and order statuses.

### 2.8 Order Items

| Column | Data Type | Constraints |
|---|---|---|
| order_id | INTEGER | Composite PRIMARY KEY, FOREIGN KEY |
| product_id | INTEGER | Composite PRIMARY KEY, FOREIGN KEY |
| quantity_ordered | INTEGER | CHECK (greater than 0) |
| quantity_delivered | INTEGER | CHECK (at least 0) |
| unit_price | NUMERIC(10,2) | CHECK (at least 0) |
| substitute_product_id | INTEGER | NULL allowed, FOREIGN KEY |

**Primary Key:** `(order_id, product_id)`

**Foreign Keys:**
- `order_id` references `orders(order_id)`.
- `product_id` references `products(product_id)`.
- `substitute_product_id` references `products(product_id)`.

**Purpose:** Stores individual products purchased in each order, including quantities and substitutions.

### 2.9 Store Inventory

| Column | Data Type | Constraints |
|---|---|---|
| store_id | INTEGER | Composite PRIMARY KEY, FOREIGN KEY |
| product_id | INTEGER | Composite PRIMARY KEY, FOREIGN KEY |
| quantity_on_hand | INTEGER | CHECK (at least 0) |
| reorder_level | INTEGER | CHECK (at least 0) |
| selling_price | NUMERIC(10,2) | CHECK (greater than 0) |
| updated_at | TIMESTAMPTZ | NOT NULL |

**Primary Key:** `(store_id, product_id)`

**Foreign Keys:**
- `store_id` references `dark_stores(store_id)`.
- `product_id` references `products(product_id)`
