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

-- B. Runner and Customer Experience

-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
WITH start_date AS (
  SELECT MIN(registration_date) AS first_date
  FROM pizza_runner.runners
)
SELECT
  FLOOR((r.registration_date - first_date) / 7) AS week_number,
  first_date + (FLOOR((r.registration_date - first_date) / 7))::int * 7 AS week_starting,
  COUNT(*) AS runners_signed_up
FROM pizza_runner.runners r
CROSS JOIN start_date
GROUP BY week_number, week_starting
ORDER BY week_number;

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT 
  ro.runner_id,
  ROUND(AVG(EXTRACT(EPOCH FROM (CAST(ro.pickup_time AS TIMESTAMP) - co.order_time)) / 60)::numeric, 2) AS avg_minutes
FROM runner_orders ro
JOIN customer_orders co ON ro.order_id = co.order_id
WHERE ro.pickup_time IS NOT NULL AND ro.pickup_time != 'null'
GROUP BY ro.runner_id
ORDER BY ro.runner_id;

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
SELECT 
  co.order_id,
  COUNT(co.pizza_id) AS num_pizzas,
  ROUND(
    EXTRACT(EPOCH FROM (CAST(ro.pickup_time AS TIMESTAMP) - MIN(co.order_time)))::numeric / 60,
    2
  ) AS prep_minutes -- MIN order time ensures to take the orher time only one in multi row orders
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
WHERE ro.pickup_time IS NOT NULL AND ro.pickup_time != 'null'
GROUP BY co.order_id, ro.pickup_time
ORDER BY co.order_id;

-- 4. What was the average distance travelled for each customer?
SELECT 
  co.customer_id,
  ROUND(AVG(CAST(REPLACE(ro.distance, 'km', '') AS numeric)), 2) AS avg_distance
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
WHERE ro.distance IS NOT NULL AND ro.distance != 'null'
GROUP BY co.customer_id
ORDER BY avg_distance;

-- 5. What was the difference between the longest and shortest delivery times for all orders?
SELECT
 MAX(CAST(REGEXP_REPLACE(duration, '[^0-9]', '', 'g') AS numeric))-MIN(CAST(REGEXP_REPLACE(duration, '[^0-9]', '', 'g') AS numeric)) AS delivery_time_diff
 FROM runner_orders
 WHERE duration!='null'
 ORDER BY delivery_time_diff;
 
-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT
  runner_id,
  order_id,
  ROUND(
    CAST(REPLACE(distance, 'km', '') AS numeric) / 
    CAST(REGEXP_REPLACE(duration, '[^0-9]', '', 'g') AS numeric),
    2
  ) AS speed_km_per_min
FROM runner_orders
WHERE 
  duration IS NOT NULL AND duration != 'null'
  AND distance IS NOT NULL AND distance != 'null'
ORDER BY runner_id, order_id;

-- 7. What is the successful delivery percentage for each runner?
WITH success_deliveries AS (
  SELECT 
    runner_id,
    COUNT(order_id) AS success_count
  FROM runner_orders
  WHERE cancellation IS NULL OR cancellation = '' OR cancellation = 'null'
  GROUP BY runner_id
)

SELECT 
  ro.runner_id,
  ROUND(sd.success_count::numeric / COUNT(ro.order_id) * 100, 2) AS success_rate
FROM runner_orders ro
JOIN success_deliveries sd ON ro.runner_id = sd.runner_id
GROUP BY ro.runner_id, sd.success_count
ORDER BY ro.runner_id;
