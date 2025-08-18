/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
SELECT
  	s.customer_id as customer,
    sum(m.price) as total_amount
FROM dannys_diner.sales as s
JOIN dannys_diner.menu as m
ON s.product_id=m.product_id
GROUP BY s.customer_id
ORDER BY total_amount DESC;

-- 2. How many days has each customer visited the restaurant?
SELECT
  	customer_id as customer,
    COUNT(DISTINCT order_date) as days
FROM dannys_diner.sales
GROUP BY customer_id
ORDER BY days DESC;

-- 3. What was the first item from the menu purchased by each customer?
SELECT
  	s.customer_id as customer,
    m.product_name as item_purchased
FROM dannys_diner.sales as s
JOIN dannys_diner.menu as m
ON s.product_id=m.product_id
WHERE s.order_date = (
  SELECT MIN(order_date)
  FROM sales
  WHERE customer_id = s.customer_id
);

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT
    m.product_name as item_purchased,
    COUNT(s.product_id) as times_purchased
FROM dannys_diner.sales as s
JOIN dannys_diner.menu as m
ON s.product_id=m.product_id
GROUP BY item_purchased
ORDER BY times_purchased DESC
LIMIT 1;
-- Optimized
WITH agg AS (
  SELECT product_id, COUNT(*) AS times_purchased
  FROM sales
  GROUP BY product_id
)
SELECT m.product_name AS item_purchased, a.times_purchased
FROM agg a
JOIN menu m USING (product_id)
ORDER BY a.times_purchased DESC
FETCH FIRST 1 ROW WITH TIES;  -- Postgres 13+


-- 5. Which item was the most popular for each customer?
-- counts per (customer, product)
WITH counts AS (
  SELECT
    s.customer_id,
    s.product_id,
    COUNT(*) AS times_purchased
  FROM sales AS s
  GROUP BY s.customer_id, s.product_id
),
-- max count per customer
max_counts AS (
  SELECT
    customer_id,
    MAX(times_purchased) AS max_times
  FROM counts
  GROUP BY customer_id
)
SELECT
  c.customer_id,
  m.product_name AS item_purchased,
  c.times_purchased
FROM counts AS c
JOIN max_counts AS mx
  ON mx.customer_id = c.customer_id
 AND mx.max_times   = c.times_purchased
JOIN menu AS m
  ON m.product_id = c.product_id
ORDER BY c.customer_id, m.product_name;



-- 6. Which item was purchased first by the customer after they became a member?
WITH first_after AS (
  SELECT
    s.customer_id,
    MIN(s.order_date) AS first_purchase_date
  FROM sales s
  JOIN members m USING (customer_id)
  WHERE s.order_date >= m.join_date
  GROUP BY s.customer_id
)
SELECT
  f.customer_id,
  m.product_name AS item_purchased
FROM first_after f
JOIN sales s
  ON s.customer_id = f.customer_id
 AND s.order_date  = f.first_purchase_date
JOIN menu m
  ON m.product_id = s.product_id
ORDER BY f.customer_id, m.product_name;


-- 7. Which item was purchased just before the customer became a member?
WITH first_before AS (
  SELECT
    s.customer_id,
    MAX(s.order_date) AS last_purchase_date
  FROM sales s
  JOIN members m USING (customer_id)
  WHERE s.order_date < m.join_date
  GROUP BY s.customer_id
)
SELECT
  f.customer_id,
  m.product_name AS item_purchased
FROM first_before f
JOIN sales s
  ON s.customer_id = f.customer_id
 AND s.order_date  = f.last_purchase_date
JOIN menu m
  ON m.product_id = s.product_id
ORDER BY f.customer_id, m.product_name;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT
  mem.customer_id,
  COUNT(*)              AS total_items,
  SUM(m.price)          AS amount_spent
FROM members AS mem
JOIN sales   AS s  ON s.customer_id = mem.customer_id
JOIN menu    AS m  ON m.product_id  = s.product_id
WHERE s.order_date < mem.join_date   
GROUP BY mem.customer_id
ORDER BY mem.customer_id;
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT
  s.customer_id,
  SUM(
    CASE 
      WHEN m.product_name = 'sushi' THEN m.price * 10 * 2  -- sushi has 2x multiplier
      ELSE m.price * 10
    END
  ) AS total_points
FROM sales AS s
JOIN menu  AS m ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY total_points DESC;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

SELECT
  s.customer_id,
  SUM(
    CASE
      -- 2x on ALL items during the first 7 days after join (inclusive)
      WHEN s.order_date >= mem.join_date
       AND s.order_date <  mem.join_date + INTERVAL '7 days'
        THEN m.price * 10 * 2

      -- Outside promo window: sushi gets 2x, others 1x
      WHEN m.product_name = 'sushi'
        THEN m.price * 10 * 2
      ELSE
        m.price * 10
    END
  ) AS total_points
FROM sales   AS s
JOIN members AS mem ON mem.customer_id = s.customer_id
JOIN menu    AS m   ON m.product_id    = s.product_id
WHERE s.order_date < DATE '2021-02-01'   -- end of January
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- Bonus Question
SELECT
  s.customer_id,
  s.order_date,
  m.product_name,
  m.price,
	CASE
    	WHEN mem.join_date IS NOT NULL AND s.order_date >= mem.join_date THEN 'Y'
    	ELSE 'N'
 	END AS member
FROM sales AS s
JOIN menu AS m
  ON s.product_id = m.product_id
LEFT
JOIN members AS mem
  ON s.customer_id = mem.customer_id
ORDER BY s.customer_id, s.order_date,m.price DESC
;

