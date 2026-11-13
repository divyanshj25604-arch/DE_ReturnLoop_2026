
-- =========================================================
-- Team T0073 | ReturnLoop | DE Checkpoint 1
-- Blinkit Grocery Delivery Database
-- PostgreSQL 15
-- =========================================================

CREATE SCHEMA IF NOT EXISTS blinkit;

SET search_path TO blinkit, public;

-- 1. CITIES
CREATE TABLE cities (
    city_id INTEGER PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,

    CONSTRAINT chk_city_name
        CHECK (LENGTH(TRIM(city_name)) > 0)
);

-- 2. DARK STORES
CREATE TABLE dark_stores (
    store_id INTEGER PRIMARY KEY,
    store_code VARCHAR(30) NOT NULL UNIQUE,
    city_id INTEGER NOT NULL,
    latitude NUMERIC(10,7) NOT NULL,
    longitude NUMERIC(10,7) NOT NULL,
    opened_on DATE NOT NULL,
    is_active BOOLEAN NOT NULL,
    max_daily_orders INTEGER NOT NULL,

    CONSTRAINT fk_store_city
        FOREIGN KEY (city_id)
        REFERENCES cities(city_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_store_code_format
        CHECK (store_code ~ '^[A-Z]{3}-[A-Z]{3}-[0-9]{2}$'),

    CONSTRAINT chk_store_latitude
        CHECK (latitude BETWEEN -90 AND 90),

    CONSTRAINT chk_store_longitude
        CHECK (longitude BETWEEN -180 AND 180),

    CONSTRAINT chk_store_capacity
        CHECK (max_daily_orders > 0)
);

-- 3. CATEGORIES
CREATE TABLE categories (
    category_id INTEGER PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    is_perishable BOOLEAN NOT NULL
);

-- 4. PRODUCTS
CREATE TABLE products (
    product_id INTEGER PRIMARY KEY,
    sku VARCHAR(30) NOT NULL UNIQUE,
    product_name VARCHAR(255) NOT NULL,
    brand VARCHAR(100) NOT NULL,
    category_id INTEGER NOT NULL,
    pack_size VARCHAR(50) NOT NULL,
    mrp NUMERIC(10,2) NOT NULL,
    shelf_life_days INTEGER,
    is_active BOOLEAN NOT NULL,

    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id)
        REFERENCES categories(category_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_product_sku_format
        CHECK (sku ~ '^BK[0-9]{8}$'),

    CONSTRAINT chk_product_mrp
        CHECK (mrp > 0),

    CONSTRAINT chk_product_shelf_life
        CHECK (shelf_life_days IS NULL OR shelf_life_days > 0)
);

-- 5. CUSTOMERS
CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(255) UNIQUE,
    city_id INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_customer_city
        FOREIGN KEY (city_id)
        REFERENCES cities(city_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_customer_phone
        CHECK (phone ~ '^[0-9]{10}$'),

    CONSTRAINT chk_customer_email
        CHECK (email IS NULL OR email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- 6. RIDERS
CREATE TABLE riders (
    rider_id INTEGER PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL UNIQUE,
    store_id INTEGER NOT NULL,
    joined_on DATE NOT NULL,
    status VARCHAR(20) NOT NULL,

    CONSTRAINT fk_rider_store
        FOREIGN KEY (store_id)
        REFERENCES dark_stores(store_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_rider_phone
        CHECK (phone ~ '^[0-9]{10}$'),

    CONSTRAINT chk_rider_status
        CHECK (status IN ('ACTIVE', 'ON_LEAVE', 'EXITED'))
);

-- 7. ORDERS
CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    store_id INTEGER NOT NULL,
    rider_id INTEGER,
    placed_at TIMESTAMPTZ NOT NULL,
    packed_at TIMESTAMPTZ,
    picked_up_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    promised_minutes INTEGER NOT NULL DEFAULT 10,
    subtotal NUMERIC(10,2) NOT NULL,
    delivery_fee NUMERIC(10,2) NOT NULL,
    handling_fee NUMERIC(10,2) NOT NULL,
    small_cart_fee NUMERIC(10,2) NOT NULL,
    total_amount NUMERIC(10,2) NOT NULL,
    payment_method VARCHAR(20) NOT NULL,
    status VARCHAR(30) NOT NULL,

    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_store
        FOREIGN KEY (store_id)
        REFERENCES dark_stores(store_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_rider
        FOREIGN KEY (rider_id)
        REFERENCES riders(rider_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_promised_minutes
        CHECK (promised_minutes > 0),

    CONSTRAINT chk_order_fees
        CHECK (
            subtotal >= 0 AND
            delivery_fee >= 0 AND
            handling_fee >= 0 AND
            small_cart_fee >= 0
        ),

    CONSTRAINT chk_order_total_calculation
        CHECK (total_amount = subtotal + delivery_fee + handling_fee + small_cart_fee),

    CONSTRAINT chk_payment_method
        CHECK (payment_method IN ('UPI', 'COD', 'WALLET', 'CARD')),

    CONSTRAINT chk_order_status
        CHECK (status IN ('DELIVERED', 'CANCELLED', 'PACKING', 'OUT_FOR_DELIVERY', 'PLACED')),

    CONSTRAINT chk_order_timeline
        CHECK (
            (packed_at IS NULL OR packed_at >= placed_at) AND
            (picked_up_at IS NULL OR packed_at IS NULL OR picked_up_at >= packed_at) AND
            (delivered_at IS NULL OR picked_up_at IS NULL OR delivered_at >= picked_up_at)
        )
);

-- 8. ORDER ITEMS
CREATE TABLE order_items (
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity_ordered INTEGER NOT NULL,
    quantity_delivered INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    substitute_product_id INTEGER,

    CONSTRAINT pk_order_items
        PRIMARY KEY (order_id, product_id),

    CONSTRAINT fk_item_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_item_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_item_substitute
        FOREIGN KEY (substitute_product_id)
        REFERENCES products(product_id)
        ON DELETE SET NULL,

    CONSTRAINT chk_quantity_ordered
        CHECK (quantity_ordered > 0),

    CONSTRAINT chk_quantity_delivered
        CHECK (quantity_delivered >= 0),

    CONSTRAINT chk_delivered_le_ordered
        CHECK (quantity_delivered <= quantity_ordered),

    CONSTRAINT chk_unit_price
        CHECK (unit_price >= 0),

    CONSTRAINT chk_substitute_not_self
        CHECK (substitute_product_id IS NULL OR substitute_product_id <> product_id)
);

-- 9. STORE INVENTORY
CREATE TABLE store_inventory (
    store_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity_on_hand INTEGER NOT NULL,
    reorder_level INTEGER NOT NULL,
    selling_price NUMERIC(10,2) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT pk_store_inventory
        PRIMARY KEY (store_id, product_id),

    CONSTRAINT fk_inventory_store
        FOREIGN KEY (store_id)
        REFERENCES dark_stores(store_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_inventory_quantity
        CHECK (quantity_on_hand >= 0),

    CONSTRAINT chk_reorder_level
        CHECK (reorder_level >= 0),

    CONSTRAINT chk_selling_price
        CHECK (selling_price > 0)
);

-- 10. INVENTORY MOVEMENTS
CREATE TABLE inventory_movements (
    movement_id INTEGER PRIMARY KEY,
    store_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    movement_type VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL,
    moved_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_movement_store
        FOREIGN KEY (store_id)
        REFERENCES dark_stores(store_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_movement_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_movement_store_inventory
        FOREIGN KEY (store_id, product_id)
        REFERENCES store_inventory(store_id, product_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_movement_type
        CHECK (movement_type IN ('RESTOCK', 'ADJUSTMENT', 'DAMAGE', 'EXPIRY')),

    CONSTRAINT chk_movement_quantity_by_type
        CHECK (
            (movement_type = 'RESTOCK' AND quantity > 0) OR
            (movement_type IN ('DAMAGE', 'EXPIRY') AND quantity < 0) OR
            (movement_type = 'ADJUSTMENT' AND quantity <> 0)
        )
);

-- =========================================================
-- Schema verification
-- =========================================================

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'blinkit'
ORDER BY table_name;
