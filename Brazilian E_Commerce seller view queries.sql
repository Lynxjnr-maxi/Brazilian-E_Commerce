--- SELLER REPORT/VIEW
--- should contain the seller_id_values,number of products sold,Revenue,cities,number of orders processed

GO
create or alter view seller_view as
with base_query as (
select distinct s.seller_id_values,count(product_id_values)over (partition by i.seller_id_values) as total_products,
count(i.order_id_values)over(partition by s.seller_id_values) as total_orders,
seller_city,seller_state,sum(price + freight_value) over(partition by i.seller_id_values) as Revenue,
year(order_purchase_timestamp) as year
from dbo.olist_sellers_dataset s
inner join dbo.olist_order_items_dataset i
on s.seller_id_values = i.seller_id_values
inner join dbo.olist_orders_dataset ord
on ord.order_id_values = i.order_id_values
group by s.seller_id_values,s.seller_city,year(order_purchase_timestamp),product_id_values,i.order_id_values,s.seller_state,i.seller_id_values,i.freight_value,i.price
),
calculation_cte as (
select seller_id_values,seller_city,seller_state,total_products,
    sum(case when year = 2016 then Revenue else 0 end) over(partition by seller_id_values) as Revenue_2016,
    sum(case when year = 2017 then Revenue else 0 end) over(partition by seller_id_values) as Revenue_2017,
    sum(case when year = 2018 then Revenue else 0 end) over(partition by seller_id_values) as Revenue_2018,
sum(Revenue)over(partition by seller_id_values) as total_revenue,total_orders
from base_query
group by seller_id_values,total_products,seller_city,year,Revenue,total_orders,seller_state
)
select * from calculation_cte 
GO

--- create another view to eliminate the duplicate 
GO
create or alter view dbo.Seller_View_Clean as
with ranked as (
    select *,
        row_number() over (partition by seller_id_values order by Revenue_2018 desc) as row_num
from dbo.seller_view
)
select 
    seller_id_values, seller_city,seller_state, total_products, total_orders,Revenue_2016, Revenue_2017, 
    Revenue_2018,total_revenue
from ranked
where row_num = 1
GO