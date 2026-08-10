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
