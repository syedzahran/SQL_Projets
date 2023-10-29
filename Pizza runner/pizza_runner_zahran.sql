USE pizza_runner;

SELECT * FROM customer_orders;

-- The customer_order table has inconsistent data types. We must first clean the data before answering any questions. The exclusions and extras columns contain values that are either 'null' (text), null (data type) or '' (empty).

-- We will create a temporary table where all forms of null will be transformed to NULL (data type).

DROP TABLE IF EXISTS customer_orders_cleaned;
CREATE TEMPORARY TABLE customer_orders_cleaned AS(
	SELECT order_id, customer_id,pizza_id,
    CASE 
		WHEN exclusions='' OR exclusions ='null' OR exclusions='NaN' THEN NULL
        ELSE exclusions
        END AS exclusions,
	CASE
		WHEN extras = '' OR extras LIKE 'null' OR extras = 'NaN' THEN NULL
			ELSE extras
		END AS extras,
		order_time
	FROM
		pizza_runner.customer_orders
);
      
SELECT * 
FROM customer_orders_cleaned;


SELECT * 
FROM pizza_runner.runner_orders;

-- The runner_order table has inconsistent data types. We must first clean the data before answering any questions. The distance and duration columns have text and numbers.
-- We will remove the text values and convert to numeric values.
-- We will convert all 'null' (text) and 'NaN' values in the cancellation column to NULL (data type).
-- We will convert the pickup_time (varchar) column to a timestamp data type.

DROP TABLE IF EXISTS runner_orders_cleaned;
CREATE TEMPORARY TABLE runner_orders_cleaned AS (
  SELECT
    order_id,
    runner_id,
    CASE
      WHEN pickup_time = 'null' THEN NULL
      ELSE pickup_time
    END AS pickup_time,
    NULLIF(
      CONVERT(
        REGEXP_REPLACE(distance, '[^0-9.]', ''),
        DECIMAL(10, 2)
      ),
      NULL
    ) AS distance,
    NULLIF(
      CONVERT(
        REGEXP_REPLACE(duration, '[^0-9.]', ''),
        DECIMAL(10, 2)
      ),
      NULL
    ) AS duration,
    CASE
      WHEN cancellation LIKE 'null' OR cancellation LIKE 'NaN' OR cancellation LIKE '' THEN NULL
      ELSE cancellation
    END AS cancellation
  FROM pizza_runner.runner_orders
);


SELECT * 
FROM runner_orders_cleaned;

-- Part A. Pizza Metrics

-- 1. How many pizzas were ordered?

SELECT count(*) as number_of_orders 
FROM customer_orders_cleaned;

-- 2. How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id)
AS unique_orders 
FROM customer_orders_cleaned;

-- 3. How many successful orders were delivered by each runner?

SELECT runner_id,COUNT(order_id) AS successful_orders
FROM
	runner_orders_cleaned
WHERE
	cancellation IS NULL
GROUP BY
	runner_id
ORDER BY
	successful_orders DESC;
    
-- 4. How many of each type of pizza was delivered?

SELECT distinct pizza_name,count(pizza_name) as delivery_count
from customer_orders_cleaned  t1
JOIN 
  pizza_names t2
ON
  t2.pizza_id = t1.pizza_id
JOIN 
  runner_orders_cleaned  t3
ON
  t1.order_id = t3.order_id
WHERE
  cancellation IS NULL
GROUP BY
  t2.pizza_name
ORDER BY
  delivery_count DESC;
  
-- 5. How many Vegetarian and Meatlovers were ordered by each customer?

SELECT customer_id,
SUM(
	CASE 
		WHEN pizza_id=1 THEN 1
        ELSE 0
	END
    ) AS meat_lovers,
SUM(
	CASE 
		WHEN pizza_id=2 THEN 1
        ELSE 0
	END
    ) AS vegetarian
FROM customer_orders_cleaned
GROUP BY customer_id;

-- 6. What was the maximum number of pizzas delivered in a single order?

WITH order_count_cte AS (
  SELECT	
  	t1.order_id,
  	COUNT(t1.pizza_id) AS n_orders
  FROM 
  	customer_orders_cleaned t1
  JOIN 
  	runner_orders_cleaned t2
  ON 
  	t1.order_id = t2.order_id
  WHERE
  	t2.cancellation IS NULL
  GROUP BY 
  	t1.order_id
)
SELECT
  MAX(n_orders) AS max_delivered_pizzas
FROM order_count_cte;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

SELECT t1.customer_id,
SUM(
	CASE
		WHEN t1.exclusions IS NOT NULL OR t1.extras IS NOT NULL THEN 1
        ELSE 0
        END
        ) AS with_changes,
SUM(
	CASE 
		WHEN t1.exclusions IS NULL AND t1.extras IS NULL THEN 1
        ELSE 0
        END
        ) AS without_changes
FROM customer_orders_cleaned t1
JOIN runner_orders_cleaned t2
USING (order_id)
WHERE t2.cancellation IS NULL
GROUP BY t1.customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?

SELECT
  SUM(
  	CASE
  		WHEN t1.exclusions IS NOT NULL AND t1.extras IS NOT NULL THEN 1
  		ELSE 0
  	END
  ) AS number_of_pizzas
FROM 
  customer_orders_cleaned AS t1
JOIN 
  runner_orders_cleaned AS t2
ON 
  t1.order_id = t2.order_id
WHERE 
  t2.cancellation IS NULL;
  

-- 9. What was the total volume of pizzas ordered for each hour of the day?

SELECT Extract(hour FROM order_time) as hour_of_day,count(*) as number_of_pizzas
FROM customer_orders_cleaned
WHERE 
  order_time IS NOT NULL
GROUP BY 
  hour_of_day
ORDER BY 
  hour_of_day;
  
-- 10. What was the volume of orders for each day of the week?

SELECT
  DAYNAME(order_time) AS day_of_week,
  COUNT(*) AS number_of_pizzas
FROM 
  customer_orders_cleaned
GROUP BY 
  day_of_week
ORDER BY 
 DAYOFWEEK(order_time);
 
 -- Part B. Runner and Customer Experience
 
 -- 1. Is there any relationship between the number of pizzas and how long the order takes to prepare?
 
 SELECT t1.order_id,count(pizza_id) as number_of_pizza,
 (t2.pickup_time - t1.order_time) as prep_time
 FROM customer_orders_cleaned t1
 JOIN runner_orders_cleaned t2
 USING (order_id)
 WHERE 
  	t2.pickup_time IS NOT NULL
 GROUP BY t1.order_id
 ORDER BY number_of_pizza;
 
 -- 2.What was the average distance traveled for each customer?
 
 SELECT t1.customer_id,ROUND(AVG(t2.distance),2) as distance 
 FROM customer_orders_cleaned t1
 JOIN runner_orders_cleaned t2
 USING (order_id)
 WHERE 
  	t2.pickup_time IS NOT NULL
GROUP BY t1.customer_id;

-- 3. What was the average distance traveled for each runner?

SELECT t2.runner_id,ROUND(AVG(t2.distance),2) as distance 
 FROM customer_orders_cleaned t1
 JOIN runner_orders_cleaned t2
 USING (order_id)
 WHERE 
  	t2.pickup_time IS NOT NULL
GROUP BY t2.runner_id;


-- 4. What was the average speed for each runner for each delivery and do you notice any trend for these values?

WITH customer_order_count AS (
  SELECT
  	customer_id,
  	order_id,
  	order_time,
  	COUNT(pizza_id) AS n_pizzas
  FROM 
  	customer_orders_cleaned
  GROUP BY 
  	customer_id,
  	order_id,
  	order_time		
)
SELECT
  t2.customer_id,
  t1.order_id,
  t1.runner_id,
  t2.n_pizzas,
  t1.distance,
  t1.duration,
  ROUND(60 * t1.distance / t1.duration, 2) AS avg_speed_kph,
  ROUND((60 * t1.distance / t1.duration) / 1.609, 2) AS avg_speed_mph
FROM
  runner_orders_cleaned AS t1
JOIN
  customer_order_count AS t2
ON
  t1.order_id = t2.order_id
WHERE
  t1.pickup_time IS NOT NULL
ORDER BY
  order_id;
  
-- Part C. Ingredient Optimization

select * from pizza_recipes;

-- We will create a temp table with the unnested array of pizza toppings.

DROP TEMPORARY TABLE IF EXISTS recipe_toppings;
CREATE TEMPORARY TABLE recipe_toppings AS (
    SELECT
        t1.pizza_id,
        t1.pizza_name,
        CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(t2.toppings, ',', numbers.n), ',', -1) AS DECIMAL) AS single_topping
    FROM 
        pizza_names AS t1
    JOIN 
        pizza_recipes AS t2
    JOIN (SELECT 1 AS n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 
        UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10
        UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15) AS numbers
    ON CHAR_LENGTH(t2.toppings) - CHAR_LENGTH(REPLACE(t2.toppings, ',', '')) >= numbers.n - 1
    ON t1.pizza_id = t2.pizza_id
);

select * from recipe_toppings;

-- 1. What are the standard ingredients for each pizza?

	WITH pizza_toppings_recipe AS (
	SELECT
		t1.pizza_name,
		t2.topping_name
	FROM 
		recipe_toppings AS t1
	JOIN
		pizza_toppings AS t2
	ON
		t1.single_topping = t2.topping_id
	ORDER BY
		t1.pizza_name
)
SELECT
	pizza_name,
	GROUP_CONCAT(topping_name SEPARATOR ', ') AS toppings
FROM
	pizza_toppings_recipe
GROUP BY
	pizza_name;
    
-- 2. What was the most commonly added extra?

DROP TABLE IF EXISTS get_extras;
CREATE TEMPORARY TABLE get_extras AS (
   SELECT
      @row_number := @row_number + 1 AS row_id,
      order_id,
      TRIM(BOTH ',' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(extras, ',', @row_number), ',', -1)) + 0 AS extras,
      COUNT(*) AS extras_count
   FROM 
      (SELECT @row_number := 0) AS init
      CROSS JOIN customer_orders_cleaned
   WHERE
      extras IS NOT NULL
   GROUP BY 
      order_id,
      extras
);
WITH most_common_extra AS (
  SELECT
  	extras,
  	SUM(extras_count) AS total_extras
  FROM
  	get_extras
  GROUP BY
  	extras
)
SELECT
  t1.topping_name AS most_common_topping
FROM 
  pizza_toppings AS t1
JOIN 
  most_common_extra AS t2
ON 
  t2.extras = t1.topping_id
ORDER BY
  total_extras DESC
LIMIT 1;


-- 3. What was the most common exclusion?

DROP TABLE IF EXISTS get_exclusions;
CREATE TEMPORARY TABLE get_exclusions AS (
   SELECT
      @row_number := @row_number + 1 AS row_id,
      order_id,
      TRIM(BOTH ',' FROM SUBSTRING_INDEX(SUBSTRING_INDEX(exclusions, ',', @row_number), ',', -1)) + 0 AS exclusions,
      COUNT(*) AS total_exclusions
   FROM 
      (SELECT @row_number := 0) AS init
      CROSS JOIN customer_orders_cleaned
   WHERE
      exclusions IS NOT NULL
   GROUP BY 
      order_id,
      extras
);
WITH most_common_exclusion AS (
  SELECT
  	exclusions,
  	SUM(total_exclusions) AS total_exclusions
  FROM
  	get_exclusions
  GROUP BY
  	exclusions
)
SELECT
  t1.topping_name AS most_excluded_topping
FROM 
  pizza_toppings AS t1
JOIN 
  most_common_exclusion AS t2
ON 
  t2.exclusions = t1.topping_id
ORDER BY
  total_exclusions DESC
LIMIT 1;


-- Part D. Pricing & Ratings

-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?

SELECT SUM(
 CASE
	WHEN pizza_id=1 THEN 12
    WHEN pizza_id = 2 THEN 10
   END 
   ) AS pizza_revenue_before_cancellation 
FROM customer_orders_cleaned;

-- 2. What if there was an additional $1 charge for any pizza extras?

DROP TABLE IF EXISTS extras_count;
CREATE TEMPORARY TABLE extras_count AS
(
	WITH single_toppings AS (
    SELECT 
        order_id,
        TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(extras, ',', numbers.n), ',', -1)) AS each_extra
    FROM 
        customer_orders_cleaned
    JOIN (
        SELECT 1 AS n UNION ALL
        SELECT 2 UNION ALL
        SELECT 3 
    ) AS numbers
    ON CHAR_LENGTH(extras) - CHAR_LENGTH(REPLACE(extras, ',', '')) >= numbers.n - 1
)
SELECT order_id,count(each_extra) as total_extras
from single_toppings
GROUP BY 
  	order_id
);
WITH calculated_totals AS
(	
	SELECT t1.order_id,SUM(
    CASE 
		WHEN t1.pizza_id=1 THEN 12
        WHEN t1.pizza_id=2 THEN 10
        END
        )AS total_price,
	total_extras
    FROM 
		customer_orders_cleaned t1
        JOIN runner_orders_cleaned t2
        USING (order_id)
        LEFT JOIN extras_count t3
        USING (order_id)
        WHERE t2.cancellation IS NULL
  GROUP BY 
  	t1.order_id,
  	t1.pizza_id,
  	t3.total_extras
)SELECT 
  SUM(total_price) | SUM(total_extras) AS total_income
FROM 
  calculated_totals;
  
-- 3. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometer traveled - how much money does Pizza Runner have left over after these deliveries?

DROP TABLE IF EXISTS runner_orders_without_cancellation;
CREATE TEMPORARY TABLE runner_orders_without_cancellation AS (
   SELECT order_id,cancellation
   FROM runner_orders_cleaned
   WHERE cancellation IS NULL
   );
  WITH  pay_for_runner AS
( 
SELECT SUM(distance * .30) as payout
FROM runner_orders_cleaned
WHERE 
  	pickup_time IS NOT NULL
),
pizza_total AS
(
SELECT t1.order_id,SUM(
	CASE	
		WHEN t1.pizza_id=1 THEN 12
        WHEN t1.pizza_id=2 THEN 10
        END
        )AS total_price
	FROM customer_orders_cleaned t1
    JOIN runner_orders_without_cancellation t2
	ON t1.order_id = t2.order_id
    WHERE t2.cancellation IS NULL
    GROUP BY t1.order_id
)
SELECT ROUND(SUM(total_price) - (SELECT payout FROM pay_for_runner), 2) as total_revenue
 FROM pizza_total;
 
 -- Extra Question
 
 --  1. If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?
 
 DROP TABLE IF EXISTS temp_pizza_names;
CREATE TEMPORARY TABLE temp_pizza_names AS (
  SELECT *
	FROM
		pizza_runner.pizza_names
);

INSERT INTO temp_pizza_names
VALUES
(3, 'Supreme');


DROP TABLE IF EXISTS temp_pizza_recipes;
CREATE TABLE temp_pizza_recipes AS (
  SELECT *
	FROM
		pizza_runner.pizza_recipes
);

INSERT INTO temp_pizza_recipes
VALUES
(3, '1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12');

SELECT
  t1.pizza_id,
  t1.pizza_name,
  t2.toppings
FROM 
  temp_pizza_names AS t1
JOIN
  temp_pizza_recipes AS t2
ON
  t1.pizza_id = t2.pizza_id;

