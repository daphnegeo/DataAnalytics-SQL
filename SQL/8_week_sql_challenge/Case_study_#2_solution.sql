-- A. Pizza Metrics

-- 1. How many pizzas were ordered?
SELECT
    COUNT(*) AS total_pizzas_ordered
FROM customer_orders;

-- 2. How many unique customer orders were made?
SELECT
    COUNT(DISTINCT order_id) AS total_orders
FROM customer_orders;

-- 3. How many successful orders were delivered by each runner?
SELECT
	runner_id,
    COUNT(order_id)
FROM runner_orders
WHERE cancellation NOT ILIKE '%cancellation%'
					OR cancellation IS NULL                 
GROUP BY runner_id;

-- 4. How many of each type of pizza was delivered?
SELECT
	pn.pizza_name,
    COUNT( co.pizza_id) AS delivered_pizzas
FROM runner_orders AS ro
LEFT JOIN customer_orders AS co ON ro.order_id=co.order_id
LEFT JOIN pizza_names AS pn ON co.pizza_id = pn.pizza_id
WHERE ro.cancellation IS NULL
   OR ro.cancellation = ''
   OR ro.cancellation NOT ILIKE '%cancellation%'                 
GROUP BY pn.pizza_name
ORDER BY delivered_pizzas DESC;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?

SELECT
	co.customer_id,
    pn.pizza_name,
    COUNT(*) AS ordered_pizzas
FROM customer_orders AS co
LEFT JOIN pizza_names AS pn ON co.pizza_id = pn.pizza_id             
GROUP BY co.customer_id,pn.pizza_name
ORDER BY co.customer_id,pn.pizza_name,ordered_pizzas DESC;

-- 6. What was the maximum number of pizzas delivered in a single order?
SELECT
	co.order_id,
    COUNT( co.pizza_id) AS delivered_pizzas
FROM runner_orders AS ro
LEFT JOIN customer_orders AS co ON ro.order_id=co.order_id
WHERE ro.cancellation IS NULL
   OR ro.cancellation = ''
   OR ro.cancellation NOT ILIKE '%cancellation%'                 
GROUP BY co.order_id
ORDER BY delivered_pizzas DESC
LIMIT 1;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT
    co.customer_id,
    CASE
      WHEN ( co.exclusions IS NULL OR  co.exclusions IN ('', 'null'))
       AND ( co.extras IS NULL OR  co.extras IN ('', 'null'))
        THEN 'N'
      ELSE 'Y'
    END AS change_status,
    COUNT(*) AS delivered_pizzas
FROM customer_orders co
LEFT JOIN runner_orders AS ro ON ro.order_id=co.order_id
WHERE ro.cancellation IS NULL
   OR ro.cancellation = ''
   OR ro.cancellation NOT ILIKE '%cancellation%'   
GROUP BY  co.customer_id, change_status
ORDER BY  co.customer_id, change_status;

-- 8. How many pizzas were delivered that had both exclusions and extras?
SELECT
    COUNT(*) AS delivered_pizzas
FROM customer_orders AS co
LEFT JOIN runner_orders AS ro ON ro.order_id=co.order_id
WHERE (ro.cancellation IS NULL
   OR ro.cancellation = ''
   OR ro.cancellation NOT ILIKE '%cancellation%'   )
   AND co.exclusions IS NOT NULL AND  co.exclusions NOT IN ('', 'null')
   AND ( co.extras IS NOT NULL AND  co.extras NOT IN ('', 'null'));

-- 9. What was the total volume of pizzas ordered for each hour of the day?
SELECT
    EXTRACT(HOUR FROM order_time) AS hour_of_day,
    COUNT(*) AS pizzas_ordered
FROM customer_orders
GROUP BY EXTRACT(HOUR FROM order_time)
ORDER BY hour_of_day;

-- 10. What was the volume of orders for each day of the week?
SELECT
    EXTRACT(DOW FROM order_time) AS day_of_week, 
    COUNT(DISTINCT order_id) AS orders
FROM customer_orders
GROUP BY EXTRACT(DOW FROM order_time)
ORDER BY day_of_week;
