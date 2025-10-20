-- Joining customers table and orders table occur frequently, so it'll be good to create a view for it.

CREATE VIEW customers_order AS
SELECT *
FROM orders ord
    LEFT JOIN customers cust
        USING(customer_id);

-- Joining customers table and orders table occur frequently, so it'll be good to create a view for it.

CREATE VIEW customer_total_loyalty_points AS
SELECT 
    customer_id,
    cust.full_name,
    SUM(points_earned) AS total_loyalty_points
FROM customers cust
    LEFT JOIN loyalty_points loyp
        USING(customer_id)
GROUP BY customer_id
ORDER BY total_loyalty_points DESC;

-- Assumption: The condition of being a customer is at least one order 

-- 1. Count the total number of customers who joined in 2023.

SELECT COUNT(*) AS total_customers_2023
FROM customers
WHERE DATE_PART('year', join_date) = 2023 ;


-- 2. For each customer return customer_id, full_name, total_revenue (sum of total_amount from orders). Sort descending.

SELECT 
    customer_id,
    full_name,
    SUM(total_amount) as total_revenue
FROM customers_order
GROUP BY customer_id, full_name -- In case customer has more than one order
ORDER BY total_revenue DESC;


-- 3. Return the top 5 customers by total_revenue with their rank.

WITH customer_total_revenue as (
    -- Each customer's total revenue
    SELECT 
        customer_id,
        full_name,
        SUM(total_amount) as total_revenue
    FROM customers_order
    GROUP BY customer_id, full_name -- In case customer has more than one order
)
-- Ranking by total revenue
SELECT 
    customer_id,
    full_name,
    RANK() OVER (ORDER BY total_revenue DESC)
FROM customer_total_revenue
LIMIT 5;


-- 4. Produce a table with year, month, monthly_revenue for all months in 2023 ordered chronologically.

WITH year_month_revenue AS (
    -- Revenue by year and month
    SELECT 
        DATE_PART('year', order_date) as year,
        DATE_PART('month', order_date) as month,
        total_amount
    FROM orders
)
-- Monthly revenue
SELECT 
    year,
    month,
    SUM(total_amount) AS monthly_revenue
FROM year_month_revenue
GROUP BY year, month
ORDER BY month;


-- 5. Find customers with no orders in the last 60 days relative to 2023-12-31 (i.e., consider last active date up to 2023-12-31).
-- Return customer_id, full_name, last_order_date.

SELECT 
    customer_id,
    full_name, 
    MAX(order_date) AS last_order_date
FROM customers_order
GROUP BY customer_id, full_name
-- To have only order_date later than 60days from 2023-12-31
HAVING ('2023-12-31'::DATE - MAX(order_date)) > 60;


-- 6. Calculate average order value (AOV) for each customer: return customer_id, full_name, aov (average total_amount of their orders). Exclude customers with no orders.

SELECT 
    customer_id,
    full_name,
    ROUND(AVG(total_amount), 2) AS average_order_value
FROM customers_order
GROUP BY customer_id, full_name
ORDER BY average_order_value;


-- 7. For all customers who have at least one order, compute customer_id, full_name, total_revenue, spend_rank where spend_rank is a dense rank, highest spender = rank 1.

WITH customer_total_revenue as (
    -- Each customer's total revenue
    SELECT 
        customer_id,
        full_name,
        SUM(total_amount) as total_revenue
    FROM customers_order
    GROUP BY customer_id, full_name -- In case customer has more than one order
)
SELECT 
    customer_id,
    full_name,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS spend_rank
FROM customer_total_revenue;


-- 8. List customers who placed more than 1 order and show customer_id, full_name, order_count, first_order_date, last_order_date.

SELECT 
    customer_id,
    full_name,
    COUNT(order_id) AS order_count,
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date
FROM customers_order
GROUP BY customer_id, full_name;


-- 9. Compute total loyalty points per customer. Include customers with 0 points.

SELECT 
    customer_id,
    cust.full_name,
    SUM(points_earned) AS total_loyalty_points
FROM customers cust
    LEFT JOIN loyalty_points loyp
        USING(customer_id)
GROUP BY customer_id
ORDER BY total_loyalty_points DESC;


-- 10. Assign loyalty tiers based on total points:
--    - Bronze: < 100
--    - Silver: 100–499
--    - Gold: >= 500
    
--    Output: tier, tier_count, tier_total_points

WITH loyalty_tiers AS (
    SELECT 
        *,
        CASE 
            WHEN total_loyalty_points < 100 THEN 'Bronze'
            WHEN total_loyalty_points BETWEEN 100 AND 499 THEN 'Silver'
            ELSE 'Gold'
        END AS tier
    FROM customer_total_loyalty_points
)
SELECT 
    tier,
    COUNT(*) AS tier_count,
    SUM(total_loyalty_points) AS tier_total_points
FROM loyalty_tiers
GROUP BY tier;


-- 11. Identify customers who spent more than ₦50,000 in total but have less than 200 loyalty points. Return customer_id, full_name, total_spend, total_points.

SELECT 
    customer_id,
    cust_ord.full_name,
    SUM(total_amount) AS total_spend,
    SUM(cust_points.total_loyalty_points) AS total_points 
FROM customers_order cust_ord
    INNER JOIN customer_total_loyalty_points cust_points
        USING(customer_id)
    WHERE cust_points.total_loyalty_points < 200
GROUP BY customer_id, cust_ord.full_name
HAVING SUM(cust_ord.total_amount) > 50000;

-- 12. Flag customers as churn_risk if they have no orders in the last 90 days (relative to 2023-12-31) AND are in the Bronze tier. Return customer_id, full_name, last_order_date, total_points.

WITH loyalty_tiers AS (
    SELECT 
        *,
        CASE 
            WHEN total_loyalty_points < 100 THEN 'Bronze'
            WHEN total_loyalty_points BETWEEN 100 AND 499 THEN 'Silver'
            ELSE 'Gold'
        END AS tier
    FROM customer_total_loyalty_points
)
SELECT 
    customer_id,
    cust_ord.full_name,
    MAX(cust_ord.order_date) AS last_order_date,
    SUM(total_loyalty_points) AS total_points
FROM customers_order cust_ord
    INNER JOIN loyalty_tiers
        USING(customer_id)
        WHERE tier = 'Bronze' 
GROUP BY customer_id, cust_ord.full_name
HAVING ('2023-12-31'::DATE - MAX(cust_ord.order_date)) > 90;

