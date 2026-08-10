----------------------------------------------
--- MEASURES EXPLORATION
----------------------------------------------
--- ORDER PERFORMANCE KPIS
--- Total Orders
select year(order_purchase_timestamp) as year,count(distinct order_id) as total_orders  
from dbo.olist_orders_dataset
group by year(order_purchase_timestamp) 

--- Total Orders in each Order status
select distinct  order_status,
sum(case when year(order_purchase_timestamp) = 2016 then 1 else 0 end) as orders_2016,
sum(case when year(order_purchase_timestamp) = 2017 then 1 else 0 end) as orders_2017,
sum(case when year(order_purchase_timestamp) = 2018 then 1 else 0 end) as orders_2018
from dbo.olist_orders_dataset
group by order_status

--- late deliveries vs on-time deliveries 
select year(order_purchase_timestamp) as year,
sum(case when order_delivered_customer_date > order_estimated_delivery_date then 1  else 0 end ) as late_deliveries,
sum(case when order_delivered_customer_date < order_estimated_delivery_date then 1  else 0 end )  as on_time_deliveries
from dbo.olist_orders_dataset
group by year(order_purchase_timestamp)

--- orders that surpassed the shipping limit date
select year(order_purchase_timestamp) as year,
sum(case when order_delivered_customer_date > shipping_limit_date then 1  else 0 end ) as late_deliveries,
sum(case when order_delivered_customer_date < shipping_limit_date then 1  else 0 end )  as on_time_deliveries
from dbo.olist_orders_dataset o
inner join dbo.olist_order_items_dataset i
on i.order_id_values = o.order_id_values
group by year(order_purchase_timestamp)

select order_delivered_customer_date,shipping_limit_date, datediff(day,shipping_limit_date,order_delivered_customer_date) as dfrnc
from dbo.olist_orders_dataset o
inner join dbo.olist_order_items_dataset i
on i.order_id_values = o.order_id_values

--- Average time in days taken to approve,get to carrier,get to customer
select avg(datediff(hour,order_purchase_timestamp,order_approved_at)) as hours_taken_to_approve,
avg(datediff(day,order_approved_at,order_delivered_carrier_date)) as days_taken_to_get_to_seller,
avg(datediff(day,order_delivered_carrier_date,order_delivered_customer_date)) as days_taken_from_seller_to_customer,
avg(datediff(day,order_approved_at,order_delivered_customer_date)) as days_from_aproval_to_customer,
avg(datediff(day,order_purchase_timestamp,order_delivered_customer_date)) as total_days_delivery_time
from dbo.olist_orders_dataset 

--- Number of Orders by each seller 
select distinct o.seller_id_values,count(order_id) as total_orders
from dbo.olist_order_items_dataset o
group by o.seller_id_values
order by seller_id_values asc  

--- Number of orders by each city
select distinct s.seller_city,count( order_id) as total_orders
from dbo.olist_order_items_dataset o
inner join dbo.olist_sellers_dataset s
on s.seller_id = o.seller_id
group by seller_city

--- Number of orders by each state 
select distinct s.seller_state,count( order_id) as total_orders
from dbo.olist_order_items_dataset o
inner join dbo.olist_sellers_dataset s
on s.seller_id = o.seller_id
group by seller_state

--- which day of the week has more orders
select datename(weekday,order_purchase_timestamp) as day,format(count(order_id_values),'N0') as total_orders
from dbo.olist_orders_dataset
group by datename(weekday,order_purchase_timestamp)

--- which hour do we get most traffic from orders ( normal hours i.e early mornings up to late at night 1 A.M. there is alot of traffic)
select hour,
    sum(case when day_of_week = 'Sunday' then 1 else 0 end) as total_orders_Sunday,
    sum(case when day_of_week = 'Monday' then 1 else 0 end) as total_orders_Monday,
    sum(case when day_of_week = 'Tuesday' then 1 else 0 end) as total_orders_Tuesday,
    sum(case when day_of_week = 'Wednesday' then 1 else 0 end) as total_orders_Wednesday,
    sum(case when day_of_week = 'Thursday' then 1 else 0 end) as total_orders_Thursday,
    sum(case when day_of_week = 'Friday' then 1 else 0 end) AS total_orders_Friday,
    sum(case when day_of_week = 'Saturday' then 1 else 0 end) AS total_orders_Saturday
from(
    select 
        datepart(hour, order_purchase_timestamp) as hour,
        datename(weekday, order_purchase_timestamp) as day_of_week
    from dbo.olist_orders_dataset
) as sub
group by  hour
order by hour asc

--- monthly orders 
select month(order_purchase_timestamp) as month,
format(sum(case when year(order_purchase_timestamp) =2016 then 1 else 0 end),'N0') as total_orders_2016,
format(sum(case when year(order_purchase_timestamp) =2017 then 1 else 0 end),'N0') as total_orders_2017,
format(sum(case when year(order_purchase_timestamp) =2018 then 1 else 0 end),'N0') as total_orders_2018
from dbo.olist_orders_dataset
group by month(order_purchase_timestamp)
order by month asc

--- REVIEW KPIs
--- Relationship between order approval time and reviews P.S. slightly  indirectly proportional but orders signifiacntly decrease
with approval_time as (
select o.order_id_values,datediff(hour,order_purchase_timestamp,order_approved_at) as time_taken_to_approve,
review_score
from dbo.olist_orders_dataset o
inner join dbo.olist_order_reviews_dataset r
on o.order_id = r.order_id
),
time_segmentation  as (
select case 
       when time_taken_to_approve < 12 then 'under 12 hours'
       when time_taken_to_approve between 12 and 24 then '12 to 24 hours'
       when time_taken_to_approve between 24 and 48 then '24 to 48 hours'
       else 'over two days'
       end  as approval_time_bucket,
format(count(case when review_score = 5 then 1 end) * 100.0 /count(*),'N0') as five_star_pct,
count(order_id_values) as total_orders,
round(avg(review_score),2) as avg_review_score
from approval_time 
group by case 
       when time_taken_to_approve < 12 then 'under 12 hours'
       when time_taken_to_approve between 12 and 24 then '12 to 24 hours'
       when time_taken_to_approve between 24 and 48 then '24 to 48 hours'
       else 'over two days'
       end 
)
select * from time_segmentation

--- Relationship between the delivery time and reviews P.S  directly proportional
with delivery_time as (
select o.order_id_values,datediff(hour,order_delivered_carrier_date,order_delivered_customer_date) as time_taken_to_customer,
review_score
from dbo.olist_orders_dataset o
inner join dbo.olist_order_reviews_dataset r
on o.order_id = r.order_id
),
time_segmentation as (
select case when time_taken_to_customer < 50 then 'approx two days'
            when time_taken_to_customer between 50 and 96 then 'took four days'
            when time_taken_to_customer between 96 and 168 then 'took a week'
            when time_taken_to_customer between 168 and 336 then 'took two weeks'
            when time_taken_to_customer between 336 and 7220 then 'took a month'
            else 'more than a month'
            end as delivery_time_bucket,
count(order_id_values) as total_orders,
avg(review_score) as avg_review_score,
format(count(case when review_score = 5 then 1 end) * 100.0 /count(*),'N0') as five_star_pct
from delivery_time 
group by case when time_taken_to_customer < 50 then 'approx two days'
            when time_taken_to_customer between 50 and 96 then 'took four days'
            when time_taken_to_customer between 96 and 168 then 'took a week'
            when time_taken_to_customer between 168 and 336 then 'took two weeks'
            when time_taken_to_customer between 336 and 7220 then 'took a month'
            else 'more than a month'
            end 
)
select * from time_segmentation

--- number of orders with good and bad reviews
select format(count(order_id_values),'N0') as total_orders,
format(sum(case when review_score between 1 and 2 then 1 else 0 end),'N0') as bad_reviews,
format(sum(case when review_score = 3 then 1 else 0 end),'N0') as average_reviews,
format(sum(case when review_score between 4 and 5 then 1 else 0 end),'N0') as good_reviews
from dbo.olist_order_reviews_dataset

--- investigating the good reviews (>=3 )P.S.>3 reviews are due to stelar products,on-time delivery,=3 reviews the customers are slighly satisfied i.e the product arrived but doesn't match photo
--- in the advert,long deliveries,subpar packaging.
select review_english,review_score from dbo.olist_order_reviews_dataset where review_score >=3

--- invsetigating the bad reviews (<3) P.S product has not yet arrived after the expected deadline,inferior products,poor customer service,high shipping cost,
--- incomplete order delivered.
select review_english,review_score from dbo.olist_order_reviews_dataset where review_score <3

--- investigating why the orders were cancelled and how many were cancelled
select  'orders_cancelled_after_delivery' as measures_name,count(order_id_values) as measures_value
  from dbo.olist_orders_dataset
  where order_status ='canceled' and order_delivered_customer_date is  not null 
union all
select  'orders_cancelled_during_shipping' as measures_name ,count(order_id_values) as measures_value
  from dbo.olist_orders_dataset
  where order_status ='canceled' and order_delivered_carrier_date is not null and order_delivered_customer_date is null
union all
select 'orders_cancelled_after_approval' as measures_name, count(order_id_values) as measures_value
   from dbo.olist_orders_dataset
   where order_status ='canceled' and order_delivered_carrier_date is null and order_delivered_customer_date is null and
    order_approved_at is not null
 union all
 select 'orders_cancelled_before_approval' as measures_name ,count(order_id_values)
    from dbo.olist_orders_dataset
     where order_status ='canceled' and order_approved_at is null 
union all
   select count(order_id_values) as cancelled_orders from dbo.olist_orders_dataset where order_status ='canceled'

 
 --- Reasons for cancellation at each stage P.S( some reviews suggest the product has arrived but the order_delivered_customer_date is empty so they sometimes fall under the cancelled duting shipping
 ---- some orders are cancelled but they have arrived and have given good reviews)
 --------------------------------------
 --- 1.Cancelled after delivery
 --- order wasn't delivered,fake product
 ---------------------------------------
 --- 2.Cancelled during shipping
 --- delivery taking long,customer frustration leading to refund requests, order sent to a different post office.
 ---------------------------------------
 --- 3.Cancelled after approval
 --- product was not avaiable, expensive shipping,long delivery time,order cancelled by store,not yet invoiced,poor customer service
 --------------------------------------
 --- 4.Cancelled before approval
 --- wrong/defective product delivered,delivery taking long
 -------------------------------------
 --- There is inconsistency between the order_delivered_customer_date and actual customer experience. 
 --- Some customers say the product arrived but the relevant date fields are empty e.g the order_delivered_carrier_date → this affects classification listing reasons like 'not yet delivered' and yet not approved.

---- Relationship between Order Status and Reviews
select distinct order_status, count(distinct  o.order_id) as total_orders ,avg(review_score) as avg_score
from dbo.olist_orders_dataset o
inner join dbo.olist_order_reviews_dataset r
on o.order_id = r.order_id
group by order_status 

--- Average responnse time of reviews
select review_creation_date,review_answer_timestamp
from dbo.olist_order_reviews_dataset 

select avg(datediff(hour,review_creation_date,review_answer_timestamp)) as time_taken_for_answer
from dbo.olist_order_reviews_dataset
-------------------------------
--- REVENUE KPIs
-------------------------------
select p.order_id_values,order_item_id,product_id_values,seller_id_values,payment_sequential,payment_type,
payment_installments,payment_value,price,freight_value
from dbo.olist_order_items_dataset o
inner join dbo.olist_order_payments_dataset p
on p.order_id_values = o.order_id_values
order by order_id_values asc 

--- Total Revenue
select format(sum(payment_value),'C','pt-BR') as revenue
from dbo.olist_order_payments_dataset

select year(order_purchase_timestamp) as year,format(sum(payment_value),'C','pt-BR') as revenue
from dbo.olist_orders_dataset o
left join dbo.olist_order_payments_dataset p
on p.order_id_values = o.order_id_values
group by year(order_purchase_timestamp)  
order by year asc  

select month(order_purchase_timestamp) as month, 
format(sum(case when year(order_purchase_timestamp) =2016 then payment_value else 0 end),'N0') as total_Revenue_2016, 
format(sum(case when year(order_purchase_timestamp) =2017 then payment_value else 0 end),'N0') as total_Revenue_2017,  
format(sum(case when year(order_purchase_timestamp) =2018 then payment_value else 0 end),'N0') as total_Revenue_2018  
from dbo.olist_orders_dataset o
left join dbo.olist_order_payments_dataset p
on p.order_id_values = o.order_id_values
group by month(order_purchase_timestamp)  
order by month asc  
 
--- Total Revenue per year (less revenue because the orders table has less documented rows i.e 4,445 than the payment table)
--- Revenue per year also varies because 2016 has 3 revenue months,2017 has the whole 12 months,2018 has 10 months.
--- Revenue by order_status  
select distinct order_status,count(p.order_id_values) as total_orders,
format(sum(payment_value),'C','pt-BR') as revenue,
format(sum(payment_value)/sum(sum(payment_value)) over (),'P3','pt-BR') as pct_revenue
from dbo.olist_order_payments_dataset p
inner join dbo.olist_orders_dataset o
on o.order_id_values = p.order_id_values
group by order_status 

--- Revenue in our books (delivered) and projected earnings and lost earnings (96.34% are in our books,1.98% is projected,1.68% is cancelled)
select year(order_purchase_timestamp) as year, case 
       when order_status = 'delivered' then 'In Our Books'
       when order_status in ('approved', 'created', 'invoiced', 'processing', 'shipped') then 'Projected Earnings'
       else 'Canceled / Unavailable'
       end as financial_category,
count(o.order_id_values) as total_orders,
format(sum(payment_value),'C','pt-BR') as revenue,
format(sum(payment_value)/sum(sum(payment_value)) over (),'P','pt-BR')  as pct_revenue
from dbo.olist_orders_dataset o
inner join dbo.olist_order_payments_dataset p
on p.order_id_values = o.order_id_values
group by case 
       when order_status = 'delivered' then 'In Our Books'
       when order_status in ('approved', 'created', 'invoiced', 'processing', 'shipped') then 'Projected Earnings'
       else 'Canceled / Unavailable'
       end,year(order_purchase_timestamp)
order by year asc       

--- Average Order Value (AOV)  
select round(sum(payment_value)/count(order_id_values),2) as AOV  
from dbo.olist_order_payments_dataset    

--- Total orders with more than one payment_sequential   
select count(order_id_values) as total_orders,payment_sequential  
from dbo.olist_order_payments_dataset  
where payment_sequential >1  
group by payment_sequential  

--- Total orders paid with various payment types  
--- credit card are dominant form of payment with an almost single payment per order (1.004) but vouchers the second have 
--- a 1.362 avg which means customers are stacking multiple vouchers on one order P.S. customers are aggressively hunting for 
--- discounts and to the business lower immediate cash flow compared to credit/debit cards.
select count(order_id_values) as total_orders,payment_type,sum(payment_sequential) as total_sequentials,
round(sum(cast(payment_sequential as decimal (10,3))) * 1.0 /count(order_id_values),3) as avg_payments_per_order
from dbo.olist_order_payments_dataset 
group by payment_type

--- Total payment_installments per payment_type
--- credit card is most dominant hence main mode of payment and trustworthy for many customers,and for business incase of debt defaults,
--- or economy worsens.
select payment_type, format(sum(payment_installments),'N0') as total_installemnts
from dbo.olist_order_payments_dataset
group by payment_type

--- Investigating which payment type was used by customers who cancelled their orders 
-- many credit card and debit card users complain about not yet being invoiced and the majority have not yet received their refund after order cancellation
--- for vouchers those who have received a refund are angry because they are trapped by the same store credit 
select payment_type,order_status,review_english
from dbo.olist_orders_dataset o
inner join dbo.olist_order_payments_dataset p
on p.order_id_values =o.order_id_values
inner join dbo.olist_order_reviews_dataset r
on o.order_id_values = r.order_id_values
where order_status ='canceled' and payment_type = 'credit_card'

--- Revenue per seller
Select distinct o.seller_id_values,
    format(sum(case when year(ord.order_purchase_timestamp) = 2016 then p.payment_value else 0 end), 'C', 'pt-BR') AS Revenue_2016,
    format(sum(case when year(ord.order_purchase_timestamp) = 2017 then p.payment_value else 0 end), 'C', 'pt-BR') AS Revenue_2017,
    format(sum(case when year(ord.order_purchase_timestamp) = 2018 then p.payment_value else 0 end), 'C', 'pt-BR') AS Revenue_2018
from dbo.olist_order_payments_dataset p
inner join dbo.olist_order_items_dataset o
    on p.order_id_values = o.order_id_values
inner join dbo.olist_orders_dataset ord
    on p.order_id_values = ord.order_id_values
group by o.seller_id_values
order by sum(p.payment_value) asc

--- Revenue per city
select distinct seller_city,
    format(sum(case when year(ord.order_purchase_timestamp) = 2016 then p.payment_value else 0 end), 'C', 'pt-BR') AS Revenue_2016,
    format(sum(case when year(ord.order_purchase_timestamp) = 2017 then p.payment_value else 0 end), 'C', 'pt-BR') AS Revenue_2017,
    format(sum(case when year(ord.order_purchase_timestamp) = 2018 then p.payment_value else 0 end), 'C', 'pt-BR') AS Revenue_2018 
from dbo.olist_order_payments_dataset p
inner join dbo.olist_order_items_dataset o
    on p.order_id_values = o.order_id_values
inner join dbo.olist_orders_dataset ord
    on p.order_id_values = ord.order_id_values
inner join dbo.olist_sellers_dataset s
on s.seller_id_values = o.seller_id_values
group by s.seller_city
order by sum(p.payment_value) asc 

--- Revenue by seller state
select distinct seller_state,
    format(sum(case when year(ord.order_purchase_timestamp) = 2016 then p.payment_value else 0 end), 'C', 'pt-BR') AS Revenue_2016,
    format(sum(case when year(ord.order_purchase_timestamp) = 2017 then p.payment_value else 0 end), 'C', 'pt-BR') AS Revenue_2017,
    format(sum(case when year(ord.order_purchase_timestamp) = 2018 then p.payment_value else 0 end), 'C', 'pt-BR') AS Revenue_2018 
from dbo.olist_order_payments_dataset p
inner join dbo.olist_order_items_dataset o
    on p.order_id_values = o.order_id_values
inner join dbo.olist_orders_dataset ord
    on p.order_id_values = ord.order_id_values
inner join dbo.olist_sellers_dataset s
on s.seller_id_values = o.seller_id_values
group by s.seller_state
 
--- Investigating whether the relationship between total sellers and Revenue is directly proportional
--- The relationship is indirectly proportional; some cities with most sellers do not record highest revenue
--- in the top 6% cities in terms of revenue ,cities like guariba and lauro de freitas have few sellers but they recorded high margins ;lucrative product gap.
select seller_city,count(distinct s.seller_id_values) as total_sellers,format(sum(payment_value),'C','pt-BR') as Revenue,
count(distinct product_id) as total_products,round(avg(payment_value),2) as avg_payment_value
from dbo.olist_sellers_dataset s
inner join dbo.olist_order_items_dataset i
on s.seller_id_values = i.seller_id_values
inner join dbo.olist_order_payments_dataset p
on i.order_id_values = p.order_id_values
group by seller_city
having sum(payment_value) > 100000
order by total_sellers asc

--- Gross Revenue by product
--- There is a product lifecycle management crisis where some products that perfomed well like 'P02394' were discounted early
select distinct product_id_values,count(p.order_id_values) as total_orders,
    format(sum(case when year(ord.order_purchase_timestamp) = 2016 then (price + freight_value) else 0 end), 'C', 'pt-BR') AS Revenue_2016,
    format(sum(case when year(ord.order_purchase_timestamp) = 2017 then (price + freight_value) else 0 end), 'C', 'pt-BR') AS Revenue_2017,
    format(sum(case when year(ord.order_purchase_timestamp) = 2018 then (price + freight_value) else 0 end), 'C', 'pt-BR') AS Revenue_2018,
    format(sum(price + freight_value),'c','pt-BR') as total_Revenue
from dbo.olist_order_items_dataset i
inner join dbo.olist_order_payments_dataset p
on p.order_id_values = i.order_id_values
inner join dbo.olist_orders_dataset ord
on ord.order_id_values = p.order_id_values
group by product_id_values 
having  sum(case when year(ord.order_purchase_timestamp) = 2016 then p.payment_value else 0 end)  =0.00
and 
    sum(case when year(ord.order_purchase_timestamp) = 2018 then p.payment_value else 0 end) =0.00
and product_id_values ='P24377'

--- Net Revenue per product i.e the unit's price only
select distinct product_id_values,count(i.order_id_values) as total_orders,
    format(sum(case when year(ord.order_purchase_timestamp) = 2016 then i.price else 0 end), 'C', 'pt-BR') AS Revenue_2016,
    format(sum(case when year(ord.order_purchase_timestamp) = 2017 then i.price else 0 end), 'C', 'pt-BR') AS Revenue_2017,
    format(sum(case when year(ord.order_purchase_timestamp) = 2018 then i.price else 0 end), 'C', 'pt-BR') AS Revenue_2018
from dbo.olist_order_items_dataset i
inner join dbo.olist_orders_dataset ord
on ord.order_id_values =i.order_id_values
group by product_id_values 

--- investigating whether some of the discounted products were pulled out to matters like 'out of stock' or bad reviews
--- the results are inconclusive but some discounted products appear to have been out of stock or took long delivery periods
select  r.order_id_values,product_id_values,review_english
from dbo.olist_order_reviews_dataset r
inner join dbo.olist_order_items_dataset i
on i.order_id_values = r.order_id_values
where review_score <3

--- Revenue by product_categories
select distinct main_categories,count(distinct pr.product_id_values),
  format(sum(case when year(ord.order_purchase_timestamp) = 2016 then price + freight_value else 0 end), 'C', 'pt-BR') AS Revenue_2016,
  format(sum(case when year(ord.order_purchase_timestamp) = 2017 then  price + freight_value else 0 end), 'C', 'pt-BR') AS Revenue_2017,
  format(sum(case when year(ord.order_purchase_timestamp) = 2018 then  price + freight_value else 0 end), 'C', 'pt-BR') AS Revenue_2018
from dbo.olist_products_dataset pr
inner join dbo.olist_order_items_dataset o
on pr.product_id_values = o.product_id_values 
inner join dbo.olist_order_payments_dataset p
on o.order_id_values = p.order_id_values
inner join dbo.olist_orders_dataset ord
on ord.order_id_values = o.order_id_values
group by main_categories  

--- Revenue per customer
--- There is poor customer retention and brand loyalty with no customer being with us for more than a year  
--- CUSTOMER RETENTION (corrected: uses customer_unique_id, the true person-level identifier,  
--- not customer_id_values which is generated per-order and will always show 0% repeat)  

--- STEP 1: build the base once into a temp table so we can query it multiple times  
drop table if exists #customer_orders  

select  
    c.customer_unique_id,  
    o.order_id_values,  
    year(o.order_purchase_timestamp) as order_year  
into #customer_orders  
from dbo.olist_orders_dataset o  
inner join dbo.olist_customers_dataset c
    on o.customer_id = c.customer_id

--- STEP 2: per-customer summary (order count + years active) — also reused below
drop table if exists #customer_summary

select 
    customer_unique_id,
    count(distinct order_id_values) as order_count,
    count(distinct order_year) as years_active
into #customer_summary
from #customer_orders
group by customer_unique_id

-------------------------------------------------------
--- OUTPUT 1: Overall repeat-purchase rate (any 2+ orders, regardless of year)
-------------------------------------------------------
select 
    count(distinct customer_unique_id) as total_customers,
    sum(case when order_count > 1 then 1 else 0 end) as repeat_customers,
    format(sum(case when order_count > 1 then 1 else 0 end) * 100.0 
        / count(distinct customer_unique_id), 'N2') as repeat_customer_pct
from #customer_summary

-------------------------------------------------------
--- OUTPUT 2: Multi-year retention (active in more than one calendar year)
-------------------------------------------------------
select 
    count(distinct customer_unique_id) as total_customers,
    sum(case when years_active > 1 then 1 else 0 end) as multi_year_customers,
    format(sum(case when years_active > 1 then 1 else 0 end) * 100.0 
        / count(distinct customer_unique_id), 'N2') as multi_year_pct
from #customer_summary

-------------------------------------------------------
--- OUTPUT 3: Distribution of order counts per customer (for a histogram/chart)
-------------------------------------------------------
select order_count, count(*) as num_customers
from #customer_summary
group by order_count
order by order_count asc

--- cleanup
drop table if exists #customer_orders
drop table if exists #customer_summary


select distinct customer_id_values,year(order_purchase_timestamp) as year,count(customer_id_values) as count
from dbo.olist_orders_dataset
group by customer_id_values,year(order_purchase_timestamp)
having count(customer_id_values) >1

--- Revenue by quarter
select year(order_purchase_timestamp) as year,datepart(quarter,order_purchase_timestamp) as quarter,
format(sum(payment_value),'C','pt-BR') as revenue
from dbo.olist_orders_dataset o 
inner join dbo.olist_order_payments_dataset p
on p.order_id_values = o.order_id_values
group by year(order_purchase_timestamp),datepart(quarter,order_purchase_timestamp)
order by year(order_purchase_timestamp) asc 