create database music_store;
use music_store;

-- senior most employee based on job title:

SELECT title, concat(last_name," ", first_name) as Name
FROM employee
ORDER BY levels DESC
LIMIT 1;

-- Ans:Adams Andrew: General Manager

-- Top 5 countries having most invoices

SELECT COUNT(*) AS Total_invoices, billing_country 
FROM invoice
GROUP BY billing_country
ORDER BY Total_invoices DESC
LIMIT 5;

-- Ans: USA,Canada,Brazil,France,Germany


-- City having the best customers
-- We would like to throw a promotional Music Festival in the city we made the most money. 

SELECT 
    Billing_City, SUM(total) AS Invoice_total
FROM
    Invoice
GROUP BY Billing_City
ORDER BY Invoice_total DESC
LIMIT 1;

-- Ans: Prague, with an invoice total of 273.24


-- Best customer: The customer who has spent the most money will be declared the best customer. 

SELECT 
    Customer_Id,
    CONCAT(first_name, ' ', last_name) AS Customer_name,
    SUM(total) AS Invoice_total
FROM
    Invoice
        INNER JOIN
    customer USING (Customer_id)
GROUP BY Customer_name
ORDER BY Invoice_total DESC
LIMIT 1;

-- Ans: FrantiÅ¡ek WichterlovÃ¡(Customer id : 5) with an Invoice Total of 144.54


-- Number of all Rock Music listeners

SELECT 
    Distinct Email,CONCAT(first_name, ' ', last_name) AS Customer_name,
    genre.name as Genre
FROM customer
JOIN invoice ON invoice.customer_id = customer.customer_id
JOIN invoice_line ON invoice_line.invoice_id = invoice.invoice_id
JOIN track ON track.track_id = invoice_line.track_id
JOIN genre ON genre.genre_id = track.genre_id
WHERE genre.name = "Rock"
ORDER BY Customer_name;

SELECT 
    count(Distinct Email) as Number_of_customers
FROM customer
JOIN invoice ON invoice.customer_id = customer.customer_id
JOIN invoice_line ON invoice_line.invoice_id = invoice.invoice_id
JOIN track ON track.track_id = invoice_line.track_id
JOIN genre ON genre.genre_id = track.genre_id
WHERE genre.name = "Rock";

-- There are 58 Rock Music listeners


-- Top  Artists who have written the most rock music:

SELECT artist.artist_id, artist.name,COUNT(artist.artist_id) AS number_of_songs
FROM track
JOIN album2 ON album2.album_id = track.album_id
JOIN artist ON artist.artist_id = album2.artist_id
JOIN genre ON genre.genre_id = track.genre_id
WHERE genre.name LIKE 'Rock'
GROUP BY artist.artist_id
ORDER BY number_of_songs DESC;

-- ANS: AC/DC,Aerosmith,Audioslave,Led Zeppelin,Alanis Morissette,Alice In Chains,Frank Zappa & Captain Beefheart,Accept

-- Tracks that have a song length longer than the average song length:

SELECT name,milliseconds
FROM track
WHERE milliseconds > (
	SELECT AVG(milliseconds) AS avg_track_length
	FROM track )
ORDER BY milliseconds DESC;


-- Find which artist has earned the most according to the InvoiceLines. Now use this artist to find which customer spent the most on this artist.

WITH Best_selling_artist as
(
select artist.Name as Artist,Artist_id,
sum(Invoice_Line.Unit_Price * Invoice_Line.Quantity) as total_sales
from Artist INNER JOIN Album2 
using (Artist_Id) INNER JOIN Track
using (Album_Id) INNER JOIN Invoice_Line
using (Track_id)
Group by Artist
ORDER BY total_sales desc
limit 1
)
select C.Customer_id, concat(C.first_name," ",C.last_name),
sum(il.Unit_Price * il.Quantity) as Spends
from Customer C INNER JOIN Invoice I USING (Customer_id) 
INNER JOIN Invoice_Line il USING (Invoice_id)
INNER JOIN Track USING (Track_Id)
INNER JOIN Album2 USING (Album_id)
INNER JOIN Best_selling_artist USING (Artist_Id)
group by 1,2
order by Spends desc limit 1
;



-- AC/DC is the best selling artist and Customer Steve Murray has most spends on this artist.


-- Most popular music Genre for each country

with popular_gen as
(
Select g.Name as Genre, count(il.quantity) as Purchases,c.Country as Country,
Row_Number() over (Partition by c.Country ORDER BY count(il.quantity) desc) as ROW_NUM
FROM 
genre g INNER JOIN track t USING (genre_id)
INNER JOIN invoice_line il using (track_id)
INNER JOIN invoice i using (invoice_id)
INNER JOIN customer c using (Customer_id)
group by c.Country,genre
)
select * from popular_gen where ROW_NUM <=1
 
 -- Rock is the most popular genre for all countries except Spain and Norway, as metal is the most popular for them.
 
 
 
 -- Best Customer for each country:
 
with Customer_with_Country as
(
select C.Customer_id,concat(c.first_name," ",last_name) as Customer_name,Billing_country,Sum(total) as Total_spend,
ROW_NUMBER() OVER(Partition by Billing_country ORDER BY Sum(total) desc) as Row_num
from Customer C INNER JOIN Invoice I using (Customer_id)
Group by 2,3
ORDER BY Billing_country,Row_num
)
Select * from Customer_with_Country
where Row_num<=1;


