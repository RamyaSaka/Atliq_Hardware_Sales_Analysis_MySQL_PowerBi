select * from dim_customer limit 5;
select * from dim_product limit 5;
select * from fact_gross_price limit 5;
select * from fact_manufacturing_cost limit 5;
select * from fact_pre_invoice_deductions limit 5;
select * from fact_sales_monthly;

-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region

select market,customer from dim_customer where customer like 'Atliq Exclusive' and region like 'APAC';


-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,
-- unique_products_2020, unique_products_2021., percentage_chg

select X.A as unique_products_20202, Y.B as unique_products_2021, round((B-A)*100/A,2) as percentage_chg
FROM (
(
select count(distinct product_code) as A from fact_gross_price where fiscal_year = 2020
) X,
( select count(distinct product_code) as B from fact_gross_price where fiscal_year = 2021
) Y
);


-- 3. Provide a report with all the unique product counts for each segment 
-- and sort them in descending order of product counts.
-- The final output contains 2 fields, segment and product_count

select segment, count(distinct product_code) as product_count 
from dim_product
group by segment 
order by product_count desc;


-- 4. Which segment had the most increase in unique products in 2021 vs 2020? 
-- The final output contains these fields,
-- segment, product_count_2020, product_count_2021, difference


with CTE1 as 
(select segment as S, count(distinct dim_product.product_code) as A 
from dim_product inner join fact_sales_monthly 
on dim_product.product_code = fact_sales_monthly.product_code 
where fact_sales_monthly.fiscal_year = 2020
group by segment),
CTE2 as
(select segment as T,count(distinct dim_product.product_code) as B 
from dim_product inner join fact_sales_monthly 
on dim_product.product_code = fact_sales_monthly.product_code 
where fact_sales_monthly.fiscal_year = 2021
group by segment)

select CTE1.S as segment, CTE1.A as product_count_2020, CTE2.B as product_count_2021, (CTE2.B-CTE1.A) as difference
FROM CTE1 inner join CTE2 
where CTE1.S = CTE2.T
order by difference desc;


-- 5. . Get the products that have the highest and lowest manufacturing costs.
-- The final output should contain these fields,
-- product_code, product, manufacturing_cost

select dim_product.product_code, dim_product.product, fact_manufacturing_cost.manufacturing_cost
from dim_product inner join fact_manufacturing_cost
on dim_product.product_code = fact_manufacturing_cost.product_code
where manufacturing_cost in 
(
select max(manufacturing_cost) from fact_manufacturing_cost
union
select min(manufacturing_cost) from fact_manufacturing_cost
);


-- 6. Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
-- The final output contains these fields, customer_code, customer, average_discount_percentage

select dim_customer.customer_code, customer, pre_invoice_discount_pct as average_discount_percentage
from dim_customer inner join fact_pre_invoice_deductions
on dim_customer.customer_code = fact_pre_invoice_deductions.customer_code
where fiscal_year = '2021' and market = 'India'
order by average_discount_percentage desc
limit 5;


-- 7.  Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month.
-- This analysis helps to get an idea of low and high-performing months and take strategic decisions.
-- The final report contains these columns: Month, Year, Gross sales Amount

select monthname(fs.date) as Month, fs.fiscal_year as Year, round(sum(fs.sold_quantity * fp.gross_price),2) as gross_sales_amount
from fact_sales_monthly fs inner join fact_gross_price fp  on fs.product_code = fp.product_code 
                           inner join dim_customer dc on fs.customer_code = dc.customer_code 
where dc.customer = 'Atliq Exclusive'
group by Month,fs.fiscal_year
order by fs.fiscal_year;


-- 8  which quarter of 2020, got the maximum total_sold_quantity? 
-- The final output contains these fields sorted by the total_sold_quantity,
-- Quarter, total_sold_quantity

select case
when monthname(date) in ('April','May','June') then 'Q1'
when monthname(date) in ('July','August','September') then 'Q2'
when monthname(date) in ('October','November','December') then 'Q3' 
when monthname(date) in ('January','February','March') then 'Q4' 
END as quarter, sum(sold_quantity) as total_sold_quantity 
from fact_sales_monthly 
where fiscal_year = 2020
group by quarter
ORDER BY total_sold_quantity desc;


-- 9. . Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
-- The final output contains these fields - channel, gross_sales_mln, percentage

 WITH Output AS
(
SELECT C.channel,
       ROUND(SUM(G.gross_price*FS.sold_quantity/1000000), 2) AS Gross_sales_mln
FROM fact_sales_monthly FS JOIN dim_customer C ON FS.customer_code = C.customer_code
						   JOIN fact_gross_price G ON FS.product_code = G.product_code
WHERE FS.fiscal_year = 2021
GROUP BY channel
)
SELECT channel, CONCAT(Gross_sales_mln,' M') AS Gross_sales_mln , CONCAT(ROUND(Gross_sales_mln*100/total , 2), ' %') AS percentage
FROM
(
(SELECT SUM(Gross_sales_mln) AS total FROM Output) A,
(SELECT * FROM Output) B
)
ORDER BY percentage DESC;


-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
-- The final output contains these fields - division, product_code, product, total_sold_quantity, rank_order

 WITH Output1 AS 
(
SELECT P.division, FS.product_code, P.product, SUM(FS.sold_quantity) AS Total_sold_quantity
FROM dim_product P JOIN fact_sales_monthly FS
ON P.product_code = FS.product_code
WHERE FS.fiscal_year = 2021 
GROUP BY  FS.product_code, division, P.product
),
Output2 AS 
(
SELECT division, product_code, product, Total_sold_quantity,
        RANK() OVER(PARTITION BY division ORDER BY Total_sold_quantity DESC) AS 'Rank_Order' 
FROM Output1
)
 SELECT Output1.division, Output1.product_code, Output1.product, Output2.Total_sold_quantity, Output2.Rank_Order
 FROM Output1 JOIN Output2
 ON Output1.product_code = Output2.product_code
WHERE Output2.Rank_Order IN (1,2,3);
