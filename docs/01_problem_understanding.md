# Problem Understanding

**Project:** Blinkit 10-Minute Grocery Delivery Database  
**Team:** T0073 | **Section:** E

## 1. Business Overview

Blinkit provides grocery delivery within 10 minutes through nearby dark stores. Each store maintains its own inventory. The system manages customers, products, orders, order items, riders, stock movements and deliveries. The existing database lacks proper schema documentation, and several teams have reported performance and reporting issues.

## 2. Problems and Business Requirements

| Problem | Business Requirement | Stakeholders | Classification |
|---|---|---|---|
| P1 | Fast store assignment and product category/search results are required to maintain the 10-minute delivery promise. | Customers, Customer App Team | Customer-facing / Real-time |
| P2 | Checkout, stock availability checks, order placement and tracking must work quickly, especially during peak hours. | Customers, Customer App Team | Customer-facing / Real-time |
| P3 | Store staff need faster access to open orders, rider dispatch and automatic stock deduction after packing. | Dark-store Managers, Pickers/Packers, Riders | Customer-facing / Real-time |
| P4 | Low-stock reports, restocking information and dead-stock identification must be generated efficiently for inventory management. | Supply Chain, Replenishment Team | Reporting / Analytics |
| P5 | The category team needs an accurate list of products that have not been used as substitutes during a given month. | Category Team | Reporting / Analytics |
| P6 | Delivery SLA, order fill-rate, wastage and rider performance reports must execute efficiently. | Operations, Riders | Reporting / Analytics |
| P7 | Business teams need faster financial, growth and analytical reports covering customer cohorts, GMV, small-cart fees, loyalty and category sales, while supporting future growth. | Finance, Growth, Management | Reporting / Analytics |

## 3. Assumptions

1. PostgreSQL 15 or newer will be used for database implementation.
2. Each dark store belongs to one city and maintains its own product inventory.
3. Each order is associated with a customer and a dark store.
4. Order items record ordered quantity, delivered quantity and substitute product information.
5. Inventory movements record stock changes such as restocking, damage, expiry and adjustments.
6. The supplied CSV files represent the source data for rebuilding the database schema.

## 4. Objective

The objective is to rebuild a properly structured and constrained relational database, load the supplied data, measure query performance, optimize important queries and ensure the database can support future business growth.
