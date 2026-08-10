--- DATABSE EXPLORATION
select * from dbo.olist_order_items_dataset --- order details 
select * from dbo.olist_order_payments_dataset  --- payment details
select * from dbo.olist_order_reviews_dataset --- review details
select * from dbo.olist_orders_dataset --- order approval,order purchase,order status,estimated delivery 
select * from dbo.olist_products_dataset -- product description
select * from dbo.olist_sellers_dataset  --- seller city, seller state
select * from dbo.olist_customers_dataset  --- customer details;city,id
select * from dbo.olist_geolocation_dataset   --- geolocation details;city,state,zip code 
select * from dbo.product_category_name_translation --- product category name translation 
-------------------------------------------------------------  
--- DATA CLEANING  
-------------------------------------------------------------
--- there are columns order_id,product_id,seller_id,customer_id that are in different tables and have a unique surrogate key but for easier calculations we'll create
--- a master mapping table to add to each table that has the columns 
--- CREATE A NEW TABLE TO STORE THE MAPPING OF ORDER_ID AND ORDER_ID_VALUES TO ENSURE THAT ALL ORDER_IDS ARE INCLUDED
create table dbo.order_id_values_mapping (
order_id nvarchar(50),
order_id_values nvarchar(50)
)

insert into dbo.order_id_values_mapping (order_id, order_id_values)
select distinct order_id, 
'A' + RIGHT('00000' + CAST(ROW_NUMBER() OVER (ORDER BY order_id) AS VARCHAR(5)), 5) AS order_id_values
from (
    select order_id from dbo.olist_orders_dataset
    union 
    select order_id from dbo.olist_order_items_dataset
    union 
    select order_id from dbo.olist_order_payments_dataset
    union 
    select order_id from dbo.olist_order_reviews_dataset
) as unique_orders

--- CREATE A NEW TABLE TO STORE THE MAPPING OF PRODUCT_ID AND PRODUCT_ID_VALUES TO ENSURE THAT ALL PRODUCT_IDS ARE INCLUDED
create table dbo.product_id_values_mapping (
product_id nvarchar(50),
product_id_values nvarchar(50)
)

with unique_products as(
select product_id from dbo.olist_order_items_dataset
    union 
    select product_id from dbo.olist_products_dataset
)
insert into dbo.product_id_values_mapping (product_id, product_id_values)
select  product_id,
'P' + RIGHT('00000' + CAST(ROW_NUMBER() OVER (ORDER BY product_id) AS VARCHAR(5)), 5) AS product_id_values
from unique_products
order by product_id_values asc
    
select * from dbo.product_id_values_mapping order by product_id_values asc

--- CREATE A NEW TABLE TO STORE THE MAPPING OF SELLER_ID AND SELLER_ID_VALUES TO ENSURE THAT ALL SELLER_IDS ARE INCLUDED
create table dbo.seller_id_values_mapping (
seller_id nvarchar(50),
seller_id_values nvarchar(50)
)

insert into dbo.seller_id_values_mapping (seller_id, seller_id_values)
select distinct seller_id,
'S' + RIGHT('00000' + CAST(ROW_NUMBER() OVER (ORDER BY seller_id) AS VARCHAR(5)), 5) AS seller_id_values
from (
    select seller_id from dbo.olist_order_items_dataset
    union 
    select seller_id from dbo.olist_sellers_dataset
) as unique_sellers

select * from dbo.seller_id_values_mapping

--- CREATE A NEW TABLE TO STORE THE MAPPING OF THE CUSTOMER_ID AND CUSTOMER_ID_VALUES TO ENSURE THAT ALL CUSTOMER_IDS ARE INCLUDED
create table dbo.customer_id_values_mapping (
customer_id nvarchar(50),
customer_id_values nvarchar(50)
)

insert into dbo.customer_id_values_mapping (customer_id, customer_id_values)
select distinct customer_id,
'C' + RIGHT('00000' + CAST(ROW_NUMBER() OVER (ORDER BY customer_id) AS VARCHAR(5)), 5) AS customer_id_values
from (
    select customer_id from dbo.olist_orders_dataset
    union 
    select customer_id from dbo.olist_customers_dataset
) as unique_customers

select * from dbo.customer_id_values_mapping order by customer_id_values asc
------------------------------------------------
--- 1.dbo.olist_order_items_dataset
------------------------------------------------
--- ADD COLUMNS ORDER_ID_VALUES,SELLER_ID_VALUES AND PRODUCT_ID_VALUES
alter table dbo.olist_order_items_dataset
add order_id_values nvarchar(50),
product_id_values nvarchar(50),
seller_id_values nvarchar(50)

--- INSERT THE DATA FROM THE MASTER MAPPING TABLES
UPDATE o
SET o.order_id_values = k.order_id_values
FROM dbo.olist_order_items_dataset o
INNER JOIN dbo.order_id_values_mapping k
    ON k.order_id = o.order_id

--- dbo.product_id_values_mapping into dbo.olist_order_items_dataset
UPDATE o
SET o.product_id_values = p.product_id_values
FROM dbo.olist_order_items_dataset AS o
INNER JOIN dbo.product_id_values_mapping AS p 
    ON o.product_id = p.product_id;

--- dbo.seller_id_values_mapping into dbo.olist_order_items_dataset
update o
set o.seller_id_values = s.seller_id_values
from dbo.olist_order_items_dataset o
inner join dbo.seller_id_values_mapping s
on o.seller_id = s.seller_id

--- delete null rows
delete from dbo.olist_order_items_dataset
where order_id is null and order_item_id is null and product_id is null and order_id_values is null and product_id_values is null and seller_id_values is null

 --- find out if there any order_ids that have different seller_ids P.S. there are 1728 orders with dfrnt seller_ids
select order_id_values, count(distinct seller_id_values) as seller_count
from dbo.olist_order_items_dataset
group by order_id_values
having count(distinct seller_id_values) > 1

--- change shipping_limit_date to date format;remove the timestamp
update dbo.olist_order_items_dataset
set shipping_limit_date = CAST(shipping_limit_date AS DATE)

alter table dbo.olist_order_items_dataset
alter column shipping_limit_date date

--- round price and freight_value to 2 decimal places
update dbo.olist_order_items_dataset
set price = ROUND(price, 2), 
freight_value = ROUND(freight_value, 2)

--- look for duplicates records and delete them
with delete_dupicates as(
select *,row_number()
over (partition by order_id_values,product_id_values,seller_id_values,shipping_limit_date,price,freight_value
order by order_item_id ) as row_num
from dbo.olist_order_items_dataset
)
delete from delete_dupicates
where row_num >1
----------------------------------------------
---2.dbo.olist_order_payments_dataset
-----------------------------------------------
select * from dbo.olist_order_payments_dataset

alter table dbo.olist_order_payments_dataset
add order_id_values nvarchar(70)

--- insert data into order_id_values from the master mapping table 
UPDATE o
SET o.order_id_values = k.order_id_values
FROM dbo.olist_order_payments_dataset o
INNER JOIN dbo.order_id_values_mapping k
    ON k.order_id = o.order_id

--- delete the null rows over the table
 delete from dbo.olist_order_payments_dataset
 where order_id is null and payment_sequential is null and payment_type is null and payment_installments is null
 and payment_value is null and order_id_values is null

 --- round payment_value to 2 decimal places
 update dbo.olist_order_payments_dataset
 set payment_value = ROUND(payment_value, 2)

--- change the payment_type brazilian name 'boleto' to 'voucher' 
update dbo.olist_order_payments_dataset
set payment_type = 'voucher'
where payment_type = 'boleto'


--- look for duplicates records  P.S no duplicates found
select order_id, payment_sequential, payment_type, payment_installments, payment_value, order_id_values,
count(*) as duplicate_count
from dbo.olist_order_payments_dataset
group by order_id, payment_sequential, payment_type, payment_installments, payment_value, order_id_values
having count(*) > 1

select * from dbo.olist_order_payments_dataset
---------------------------------------------------
--- 3.dbo.olist_order_reviews_dataset
----------------------------------------------------
select * from dbo.olist_order_reviews_dataset

--- add another column review_id_values and assign common values to the review_id for easy querying and analysis
alter table dbo.olist_order_reviews_dataset
add review_id_values nvarchar(50)

with uniqueReviews as (
select distinct review_id
from dbo.olist_order_reviews_dataset
),
numberedReviews as (
select review_id,
'R' + RIGHT('00000' + CAST(ROW_NUMBER() OVER (ORDER BY review_id) AS VARCHAR(5)), 5) AS review_id_values
from uniqueReviews 
)
update t
set t.review_id_values = n.review_id_values
from dbo.olist_order_reviews_dataset t
join numberedReviews n on t.review_id = n.review_id

--- import the order_id_values from the order_id_values mapping table
UPDATE o
SET o.order_id_values = k.order_id_values
FROM dbo.olist_order_reviews_dataset o
INNER JOIN dbo.order_id_values_mapping k
    ON k.order_id = o.order_id
    
--- change the review_creation_date and review_answer_timestamp to date format;remove the timestamp
alter table dbo.olist_order_reviews_dataset
alter column review_creation_date date

alter table dbo.olist_order_reviews_dataset
alter column review_answer_timestamp date

--- the review_messags are in portuguese so for easy understanding i have translated them in google sheets and imported as [dbo].[review translation google sheets]
--- add other columns review_english (translation of review_message in english) 
alter table dbo.olist_order_reviews_dataset
add review_english nvarchar (max),
review_category nvarchar (max)

update o 
set o.review_english = r.column2
from dbo.olist_order_reviews_dataset o
inner join  [dbo].[review_translation_google_sheets] r
on r.column1= o.review_comment_message

--- look for duplicates records  P.S no duplicates found
select review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, 
review_answer_timestamp, review_id_values, order_id_values, review_english,
count(*) as duplicate_count
from dbo.olist_order_reviews_dataset
group by review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, 
review_answer_timestamp, review_id_values, order_id_values,review_english
having count(*) > 1

select * from dbo.olist_order_reviews_dataset
-----------------------------------------------------
---4.dbo.olist_orders_dataset
-----------------------------------------------------
select * from dbo.olist_orders_dataset

--- import the order_id_values from the order_id_values mapping table to the olist_orders_dataset table
alter table dbo.olist_orders_dataset
add order_id_values nvarchar(50)

UPDATE o
SET o.order_id_values = k.order_id_values
FROM dbo.olist_orders_dataset o
INNER JOIN dbo.order_id_values_mapping k
    ON k.order_id = o.order_id

--- import the customer_id_values from the customer_id_values mapping table to the olist_orders_dataset table
alter table dbo.olist_orders_dataset
add customer_id_values nvarchar(70)

UPDATE o
SET o.customer_id_values = k.customer_id_values
FROM dbo.olist_orders_dataset o
INNER JOIN dbo.customer_id_values_mapping k
    ON k.customer_id = o.customer_id

--- format the order_purchase_timestamp and the order_approved_at columns to timestamp(yyyy-mm-dd hhhh:mm:ss)
ALTER TABLE dbo.olist_orders_dataset
ALTER COLUMN order_purchase_timestamp VARCHAR(19)

alter table dbo.olist_orders_dataset
alter column order_approved_at varchar(19)

UPDATE dbo.olist_orders_dataset
SET order_purchase_timestamp = CONVERT(VARCHAR(19), order_purchase_timestamp, 120),
    order_approved_at = convert (varchar(19), order_approved_at, 120)

--- change datatype of the order_delivered_carrier_date, order_delivered_customer_date and order_estimated_delivery_date
---- from datetime to date since I don't need the time part
alter table dbo.olist_orders_dataset
alter column order_delivered_carrier_date date

alter table dbo.olist_orders_dataset
alter column order_delivered_customer_date  date

alter table dbo.olist_orders_dataset
alter column order_estimated_delivery_date date

select * from dbo.olist_orders_dataset

--- look for duplicates P.S no duplicates
select order_id,customer_id,order_status,order_purchase_timestamp,order_approved_at,order_delivered_carrier_date,
order_delivered_customer_date,order_estimated_delivery_date,count(*) as duplicates
from dbo.olist_orders_dataset
group by order_id,customer_id,order_status,order_purchase_timestamp,order_approved_at,order_delivered_carrier_date,
order_delivered_customer_date,order_estimated_delivery_date
having count(*) >1
------------------------------------------------------
--- 5.dbo.product_category_name_translation
-------------------------------------------------------
select * from dbo.product_category_name_translation

--- rename the column names
GO
EXEC sp_rename 'dbo.product_category_name_translation.informatica_acessorios', 'category_pt', 'COLUMN';
GO
EXEC sp_rename 'dbo.product_category_name_translation.computers_accessories', 'category_en', 'COLUMN';
GO

insert into dbo.product_category_name_translation (category_pt,category_en)
values('informatica_acessorios' ,'computers_accessories')

--- add another column main_categories to simply/group  the categories
alter table dbo.product_category_name_translation
add  main_categories nvarchar(80)

update dbo.product_category_name_translation
set main_categories = 
case 
    when category_en IN ('computers_accessories', 'telephony', 'consoles_games', 'audio', 
                             'tablets_printing_image', 'fixed_telephony', 'electronics', 
                             'home_appliances', 'small_appliances', 'musical_instruments', 
                             'music', 'cds_dvds_musicals', 'dvds_blu_ray', 'cine_photo','air_conditioning',
                             'computers','home_appliances_2','security_and_services','signaling_and_security') 
     then 'Electronics & Technology'
     
     when category_en LIKE '%fashion%' 
     or category_en IN ('fashion_bags_accessories', 'fashion_shoes', 'fashion_male_clothing', 
                               'fashion_underwear_beach', 'fashion_sport', 'fashio_female_clothing', 
                               'fashion_childrens_clothes', 'luggage_accessories') 
      then 'Fashion & Accessories'

      when category_en IN ('bed_bath_table', 'furniture_decor', 'housewares', 
                             'kitchen_dining_laundry_garden_furniture', 'furniture_living_room', 
                             'furniture_bedroom', 'home_confort', 'home_comfort_2', 
                             'home_construction', 'la_cuisine', 'furniture_mattress_and_upholstery', 
                             'office_furniture','pet_shop','small_appliances_home_oven_and_coffee') 
       then 'Home & Furniture'

       when category_en IN ('perfumery', 'diapers_and_hygiene') 
       then 'Beauty & Personal Care'

       when category_en LIKE '%book%' 
       or category_en IN ('sports_leisure', 'toys', 'baby', 'cool_stuff', 'party_supplies', 
                               'christmas_supplies', 'flowers', 'food', 'drinks', 'food_drink','watches_gifts') 
       then 'Sports, Toys & Leisure'

       else 'Construction tools ,arts & Others'
    end;
GO

--- add other values that are in the dbo.product_dataset
insert into dbo.product_category_name_translation (category_pt,category_en,main_categories)
values('beleza_saude','health & beauty','Beauty & Personal Care'),
('portateis_cozinha_e_preparadores_de_alimentos','portable_kitchen_and_food_preparators','Electronics & Technology'),
('pc_gamer','pc_gamer','Electronics & Technology')
  
--- find duplicate records   P.S. no duplicates
select category_pt ,category_en, main_categories,count(*) as duplicates
from dbo.product_category_name_translation
group by category_pt ,category_en, main_categories
having count(*) >1

select  * from dbo.product_category_name_translation
-------------------------------------------------
--- 6.dbo.olist_products_dataset
-------------------------------------------------
select * from dbo.olist_products_dataset

--- import the product_id_values from the product_id_values master mapping table for consistency
alter table dbo.olist_products_dataset
add product_id_values nvarchar(70)

UPDATE o
SET o.product_id_values = p.product_id_values
FROM dbo.olist_products_dataset AS o
INNER JOIN dbo.product_id_values_mapping AS p 
    ON o.product_id = p.product_id;

 --- import the product_category_name in english from the product_category_name_translation table
 alter table dbo.olist_products_dataset
 add category_en nvarchar(80)

 update o
 set o.category_en= p.category_en
 from dbo.olist_products_dataset o
 inner join dbo.product_category_name_translation p
 on o.product_category_name = p.category_pt

 update dbo.olist_products_dataset
 set category_en ='health & beauty'
 where product_category_name = 'beleza_saude'

 update dbo.olist_products_dataset
 set category_en ='portable_kitchen_and_food_preparators'
 where product_category_name = 'portateis_cozinha_e_preparadores_de_alimentos'

 update dbo.olist_products_dataset
 set category_en ='pc_gamer'
 where product_category_name ='pc_gamer'

 --- add the main categories column
 alter table dbo.olist_products_dataset
 add main_categories nvarchar(80)

  update o
 set o.main_categories= p.main_categories
 from dbo.olist_products_dataset o
 inner join dbo.product_category_name_translation p
 on o.product_category_name = p.category_pt

select distinct product_category_name,category_en,main_categories from dbo.olist_products_dataset 

--- look for duplicates   --- number of distinct rows match the number of total table rows 
select distinct product_id from dbo.olist_products_dataset
--------------------------------------------------
--- 7.dbo.olist_geolocation_dataset
--------------------------------------------------
select *  from dbo.olist_geolocation_dataset

----------------------------------------------------
--- 8.dbo.olist_sellers_dataset
----------------------------------------------------
select * from dbo.olist_sellers_dataset  

--- import the seller_id_values from the seller_id_values master mapping table
alter table dbo.olist_sellers_dataset
add seller_id_values nvarchar (80)

update o
set o.seller_id_values = s.seller_id_values
from dbo.olist_sellers_dataset o
inner join dbo.seller_id_values_mapping s
on o.seller_id = s.seller_id

--- correcting seller city for consistency and avoid duplicates
select distinct seller_city ,seller_state
from dbo.olist_sellers_dataset
where seller_city like '%ao paulo%'

update dbo.olist_sellers_dataset
set seller_city = 'sao paulo'
where seller_city like '%ao paulo' and seller_state ='SP'

update dbo.olist_sellers_dataset 
set seller_city ='angra dos reis'
where seller_city like '%angra dos reis%' and seller_state ='RJ'

update dbo.olist_sellers_dataset
set seller_city ='porto seguro'
where seller_city like  '%porto seguro%' and seller_state ='BA'

update dbo.olist_sellers_dataset
set seller_city ='minas gerais'
where seller_city like '%minas gerais%' and seller_state ='MG'

update dbo.olist_sellers_dataset
set seller_city = 'auriflama'
where seller_city like '%auriflama%' and seller_state ='SP'

update dbo.olist_sellers_dataset
set seller_city = 'aguas claras',
seller_state = 'DF'
where seller_city like '%aguas claras%' 

update dbo.olist_sellers_dataset
set seller_state = 'MG'
where seller_city like '%andradas%'

update dbo.olist_sellers_dataset
set seller_city = 'São Bernardo do Campo',
seller_state = 'SP'
where seller_city like '%ao bernardo do campo%'

update dbo.olist_sellers_dataset
set seller_city = 'Balneário Camboriú'
where seller_city like '%camboriu%' and seller_state ='SC'

update dbo.olist_sellers_dataset
set seller_city = 'Belo Horizonte',
seller_state ='MG'
where seller_city like '%belo horizont%' 

update dbo.olist_sellers_dataset
set seller_city = 'Brasilia'
where seller_city like '%rasilia%' and seller_state ='DF'

update dbo.olist_sellers_dataset
set seller_city = 'cariacica'
where seller_city like '%cariacica%' and seller_state ='ES'

update dbo.olist_sellers_dataset
set seller_city = 'caxias do sul',
seller_state ='RS'
where seller_city like '%caxias do sul%' 

update dbo.olist_sellers_dataset
set seller_city = 'chapeco',
seller_state ='SC'
where seller_city like '%chapeco%'

update dbo.olist_sellers_dataset
set seller_city = 'curitiba',
seller_state ='PR'
where seller_city like '%curitiba%'

update dbo.olist_sellers_dataset
set seller_city = 'ferraz de  vasconcelos'
where seller_city like '%ferraz de  vasconcelos%' and seller_state ='SP'

update dbo.olist_sellers_dataset
set seller_state = 'SC'
where seller_city like '%ipira%' 

insert into dbo.olist_sellers_dataset (seller_city,seller_state)
values('Ipirá','BA')

update dbo.olist_sellers_dataset
set seller_state = 'SC'
where seller_city like '%itajai%' 

update dbo.olist_sellers_dataset
set seller_state = 'SP'
where seller_city like '%jaguariuna%' 

update dbo.olist_sellers_dataset
set seller_state = 'MG'
where seller_city like '%jacutinga%'

update dbo.olist_sellers_dataset
set seller_state = 'MG'
where seller_city like '%juiz de fora%'

update dbo.olist_sellers_dataset
set seller_city = 'lages'
where seller_city like '%lages%' and seller_state ='SC'

update dbo.olist_sellers_dataset
set seller_state = 'PR'
where seller_city like '%londrina%'

update dbo.olist_sellers_dataset
set seller_state = 'PR'
where seller_city like '%marechal candido rondon%'

update dbo.olist_sellers_dataset
set seller_city = 'mogi das cruzes'
where seller_state = 'SP' and seller_city like '%mogi das cruses%' or seller_city like '%mogi das cruzes%'

update dbo.olist_sellers_dataset
set seller_city = 'novo hamburgo'
where seller_city like '%novo hamburgo%' and seller_state ='RS'

update dbo.olist_sellers_dataset
set seller_state ='SC'
where seller_city like '%palhoca%' 

update dbo.olist_sellers_dataset
set seller_state ='SC'
where seller_city like '%pinhalzinho%' 

update dbo.olist_sellers_dataset
set seller_state ='RS'
where seller_city like '%porto alegre%' 

update dbo.olist_sellers_dataset
set seller_city ='ribeirao preto'
where seller_city = 'ribeirao pretp' and seller_state  ='SP'

update dbo.olist_sellers_dataset
set seller_state ='RJ'
where seller_city like '%rio bonito%' 

update dbo.olist_sellers_dataset
set seller_state ='RJ'
where seller_city like '%rio de janeiro%' 

update dbo.olist_sellers_dataset
set seller_city ='rio de janeiro'
where seller_city like '%rio de janeiro%'

update dbo.olist_sellers_dataset
set seller_city ='São José do Rio Preto'
where seller_city = 's jose do rio preto'

UPDATE dbo.olist_sellers_dataset
SET seller_city = 'Santa Bárbara d''Oeste'
WHERE (seller_city = 'santa barbara d oeste' 
       OR seller_city = 'santa barbara d''oeste'
       OR seller_city = 'Santa Bárbara d''Oeste')
  AND seller_state = 'SP';

update dbo.olist_sellers_dataset
set seller_city ='sao jose do rio preto'
where seller_city ='sao jose do rio pret' or seller_city ='São José do Rio Preto'
and seller_state ='SP'

update dbo.olist_sellers_dataset
set seller_state ='PR',
seller_city ='São José dos Pinhais'
where seller_city='sao jose dos pinhais' or seller_city ='sao jose dos pinhas'

update dbo.olist_sellers_dataset
set seller_city='sao miguel do oeste'
where seller_city='sao miguel d''oeste' and seller_state ='SC'

update dbo.olist_sellers_dataset
set seller_city = 'são paulo'
where seller_city ='sao paluo' or seller_city ='sao paulo' or seller_city ='sao paulo - sp'
or seller_city ='sao paulo sp' or seller_city ='sao paulop' or seller_city= 'sao pauo' 
and seller_state ='SP'

update dbo.olist_sellers_dataset
set seller_city='São Bernardo do Campo'
where seller_city ='sbc' or seller_city ='sbc/sp' and seller_city = 'SP'

update dbo.olist_sellers_dataset
set seller_city = 'são paulo'
where seller_city = 'sp' or seller_city ='sp / sp' and seller_state ='SP'

update dbo.olist_sellers_dataset
set seller_state ='RJ'
where seller_city ='volta redonda'

select * from dbo.olist_sellers_dataset
---------------------------------------------
--- 9.dbo.olist_customers_dataset
---------------------------------------------
select * from dbo.olist_customers_dataset

--- import the customer_id_values from customer_id_values master mapping table (the unique_customer_id is the same as
--- the customer_id)
alter table dbo.olist_customers_dataset
add customer_id_values nvarchar (80)

update o
set o.customer_id_values = c.customer_id_values
from dbo.olist_customers_dataset c
inner join dbo.customer_id_values_mapping o
on c.customer_id = o.customer_id 

select * from dbo.olist_customers_dataset

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


select count( distinct order_id_values) from dbo.olist_order_items_dataset;
select count(order_id_values) ,order_status from dbo.olist_orders_dataset
group by order_status

select * from dbo.order_view
select * from dbo.Product_View where main_categories is null
select * from dbo.Seller_View_Clean
select * from dbo.olist_products_dataset

select *  from dbo.olist_products_dataset where main_categories is null
select * from dbo.product_category_name_translation

