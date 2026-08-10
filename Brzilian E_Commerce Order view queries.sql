--- ORDER REPORT/VIEW
--- should contain order_id_values,total_products,AOV,number of selllers involved,city,state,order_status,review
GO
create or alter view order_view as 
select distinct i.order_id_values,count(product_id_values) as products_ordered,
sum(price + freight_value) Revenue,i.seller_id_values,seller_city,seller_state,
review_score,year(order_purchase_timestamp) as year,order_status,ord.customer_id_values
from dbo.olist_order_items_dataset i
inner join dbo.olist_orders_dataset ord
on ord.order_id_values = i.order_id_values
inner join dbo.olist_order_reviews_dataset r
on r.order_id_values = i.order_id_values
inner join dbo.olist_sellers_dataset s
on s.seller_id_values = i.seller_id_values
group by i.order_id_values,order_status,ord.customer_id_values,i.seller_id_values,seller_city,seller_state,review_score,
i.price,i.freight_value,ord.order_purchase_timestamp
GO;
