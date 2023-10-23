use dannys_diner;

-- 1. What is the total amount each customer spent at the restaurant?

SELECT 
	s.customer_id,
	SUM(m.price) AS total_spent
FROM 
	dannys_diner.sales AS s
JOIN 
	dannys_diner.menu AS m
ON 
	s.product_id = m.product_id
GROUP BY 
	s.customer_id
ORDER BY 
	total_spent DESC;
    
-- 2. How many days has each customer visited the restaurant?

SELECT 
	customer_id,
	COUNT(DISTINCT order_date) AS number_of_days
FROM 
	dannys_diner.sales
GROUP BY 
	customer_id
ORDER BY 
	number_of_days DESC;
    
    
-- 3. What was the first item from the menu purchased by each customer?

WITH first_order_cte AS
(
	SELECT 
		s.customer_id,
		s.order_date,
		m.product_name,
		DENSE_RANK() OVER (
			PARTITION BY s.customer_id 
			ORDER BY s.order_date) AS ranking
		FROM 
			dannys_diner.sales AS s
		JOIN 
			dannys_diner.menu AS m
		ON 
			s.product_id = m.product_id
)
SELECT 
	DISTINCT customer_id,
	product_name
FROM 
	first_order_cte
WHERE
	ranking = 1;
    
    
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT
	m.product_name,
	COUNT(s.product_id) AS number_purchased
FROM
	dannys_diner.menu AS m
JOIN
	dannys_diner.sales AS s 
ON 
	m.product_id = s.product_id
GROUP BY 
	m.product_name
ORDER BY 
	number_purchased DESC
LIMIT 1;


-- 5. Which item was the most popular for each customer?

WITH most_popular_item_cte AS
(
	SELECT 
		s.customer_id,
		m.product_name,
		COUNT(m.product_id) AS number_purchased,
		RANK() OVER (
			PARTITION BY s.customer_id 
			ORDER BY COUNT(m.product_id) DESC) AS popularity_rank
		FROM 
			dannys_diner.sales AS s
		JOIN 
			dannys_diner.menu as m
		ON 
			s.product_id = m.product_id
		GROUP BY 
			s.customer_id,
			m.product_name
)
SELECT
	customer_id,
	product_name,
	number_purchased
FROM 
	most_popular_item_cte
WHERE 
	popularity_rank = 1;
    
    
-- 6. Which item was purchased first by the customer after they became a member?

WITH first_member_purchase_cte AS
(
	SELECT 
		t1.customer_id,
		t3.product_name,
		t1.join_date,
		t2.order_date,	
		RANK() OVER (
			PARTITION BY t1.customer_id 
			ORDER BY t2.order_date) as purchase_rank
	FROM 
		dannys_diner.members AS t1
	JOIN 
		dannys_diner.sales AS t2 
	ON 
		t1.customer_id = t2.customer_id
	JOIN 
		dannys_diner.menu AS t3 
	ON 
		t2.product_id = t3.product_id
	WHERE 
		t2.order_date >= t1.join_date
)
SELECT
	customer_id,
	join_date,
	order_date,
	product_name
FROM 
	first_member_purchase_cte
WHERE 
	purchase_rank = 1;
    

-- 7. Which item was purchased just before the customer became a member?

WITH last_nonmember_purchase_cte AS
(
	SELECT 
		t1.customer_id,
		t3.product_name,
		t2.order_date,
		t1.join_date,
		RANK() OVER (
			PARTITION BY t1.customer_id 
			ORDER BY t2.order_date DESC) as purchase_rank
		FROM 
			dannys_diner.members AS t1
		JOIN 
			dannys_diner.sales AS t2 
		ON 
			t2.customer_id = t1.customer_id
		JOIN 
			dannys_diner.menu AS  t3 
		ON 
			t2.product_id = t3.product_id
		WHERE
			t2.order_date < t1.join_date
)
SELECT 
	customer_id,
	order_date,
	join_date,
	product_name
FROM 
	last_nonmember_purchase_cte
WHERE
	purchase_rank = 1;
    

-- 8. What is the total items and amount spent for each member before they became a member?
	
WITH total_nonmember_purchase_cte AS
(
	SELECT 
		t1.customer_id,
		COUNT(t3.product_id) AS total_products,
		SUM(t3.price) AS total_spent
	FROM 
		dannys_diner.members AS t1
	JOIN 	
		dannys_diner.sales AS t2 
	ON 
		t2.customer_id = t1.customer_id
	JOIN
		dannys_diner.menu AS t3 
	ON
		t2.product_id = t3.product_id
	WHERE
		t2.order_date < t1.join_date
	GROUP BY 
		t1.customer_id
)
SELECT *
FROM 
	total_nonmember_purchase_cte
ORDER BY 
	customer_id;
    

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH total_customer_points_cte AS
(
	SELECT 
		t1.customer_id as customer,
		SUM(
			CASE
				WHEN t2.product_name = 'sushi' THEN (t2.price * 20)
				ELSE (t2.price * 10)
			END
		) AS member_points
	FROM 
		dannys_diner.sales as t1
	JOIN
		dannys_diner.menu AS t2 
	ON
		t1.product_id = t2.product_id
	GROUP BY 
		t1.customer_id
)
SELECT *
FROM
	total_customer_points_cte
ORDER BY
	member_points DESC;
    
    
 -- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi 
-- - how many points do customer A and B have at the end of January?	
   
WITH jan_member_points_cte AS
(
	SELECT 
		t1.customer_id,
		SUM(
			CASE
				WHEN t2.order_date < t1.join_date THEN
					CASE 
						WHEN t3.product_name = 'sushi' THEN (t3.price * 20)
						ELSE (t3.price * 10)
					END
				WHEN t2.order_date > (t1.join_date + 6) THEN 
					CASE 
						WHEN t3.product_name = 'sushi' THEN (t3.price * 20)
						ELSE (t3.price * 10)
					END 
				ELSE (t3.price * 20)	
			END) AS member_points
	FROM
		dannys_diner.members AS t1
	JOIN
		dannys_diner.sales AS t2 
	ON
		t2.customer_id = t1.customer_id
	JOIN
		dannys_diner.menu AS t3 
	ON
		t2.product_id = t3.product_id
	WHERE 
		t2.order_date <= '2021-01-31'
	GROUP BY 
		t1.customer_id
)
SELECT *
FROM
	jan_member_points_cte
ORDER BY
	customer_id;
    
    



