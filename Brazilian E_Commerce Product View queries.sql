--- PRODUCT REVIEW
--- The total products sold will be the count of orders since in the payment table,each order associates a 
--- payment_value which is cohesive with the product_id_values in order_items table.
--- Should contain: Product_ID,Number of transactions,Product life cycle,Average review score,Price per 
--- product,Revenue,Total Quantity Sold,Category,

GO
create or alter view Product_View as 
with base_query as (
select distinct i.Product_id_values,avg(review_score) over(partition by i.product_id_values) as avg_review,
round(avg(price) over(partition by i.product_id_values),2) as avg_price,main_categories,year(order_purchase_timestamp) as year,
count(i.order_id_values) over(partition by i.product_id_values) as total_quantity_sold,
count(i.seller_id_values) over (partition by i.product_id_values) as sellers_inolved,
round(sum(price + freight_value) over(partition by i.product_id_values),2) as transaction_value,
count(ord.customer_id_values) over (partition by i.product_id_values) as total_customers_bought
from dbo.olist_order_items_dataset i
 join dbo.olist_order_payments_dataset p
    on i.order_id_values = p.order_id_values
 join dbo.olist_order_reviews_dataset r
    on r.order_id_values =i.order_id_values
join dbo.olist_orders_dataset ord
    on ord.order_id_values = i.order_id_values
join dbo.olist_products_dataset pr
    on pr.product_id_values = i.product_id_values 
 ),
calculation_cte as (
select product_id_values,avg_review,main_categories,total_quantity_sold,
   sum(case when year = 2016 then avg_price else 0 end) as Revenue_2016,
   sum(case when year = 2017 then avg_price else 0 end )as Revenue_2017,
   sum(case when year = 2018 then avg_price else 0 end )as Revenue_2018,
case when
  sum(case when year = 2016 then avg_price else 0 end) > 0 and 
   sum(case when year = 2017 then avg_price else 0 end) > 0
                then 'First two years'
  when sum(case when year = 2018 then avg_price else 0 end) > 0 and 
  sum(case when year = 2017 then avg_price else 0 end)  > 0
                 then 'last two years'
   when   sum(case when year = 2016 then avg_price else 0 end) > 0 and 
      sum(case when year = 2018 then avg_price else 0 end) > 0
                  then 'first and last year'
when  sum(case when year = 2016 then avg_price else 0 end) > 0 and 
    sum(case when year = 2017 then avg_price else 0 end) > 0  and 
     sum(case when year = 2018 then avg_price else 0 end)  > 0 
                 then 'throughout the years'
else 'only one year'
end as product_lifecycle,
sellers_inolved,transaction_value,total_customers_bought
from base_query
group by sellers_inolved,transaction_value,product_id_values,avg_review,main_categories,total_quantity_sold,total_customers_bought
)
select * from calculation_cte 
GO;