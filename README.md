# Project Background
Olist is a Brazilian tech unicorn and retail-as-a-service platform headquartered in Curitiba, Brazil.
It helps small and medium-sized businesses (SMBs) sell across major online marketplaces and digital channels through a single, unified ecosystem — one dashboard for many marketplaces.

This project analyzes Olist’s public marketplace dataset, covering commercial activity from September 2016 through October 2018.

Measure key performance indicators across:
- Revenue growth and composition
- Seller performance and concentration
- Category and product performance
-  Customer retention and lifespan
-  Customer satisfaction and reviews
-  Operational friction (cancellations, delivery, fulfillment)

# Data Structure
The Olist marketplace dataset contains eight core tables, connected primarily through order and product identifiers: 
<img width="2486" height="1496" alt="HRhd2Y0" src="https://github.com/user-attachments/assets/d6026087-461e-41a5-986e-838035547727" />

# Executive Summary
## Revenue Findings
The dataset starts in September 2016 and ends in October 2018, so a clean year-over-year comparison is not possible. Instead, we focus on monthly performance.

Total revenue across the period reached R$16.01 million, with 2018 contributing R$8.70 million compared with R$7.25 million in 2017. The average order value(ATV) settled at R$160.99 across nearly 100,000 orders. November 2017 stood out as the strongest month, with more than 7,500 orders, while the first half of 2018 remained consistently high. Importantly, 96.3% of all revenue was successfully captured — only a small fraction leaked into cancellations or unavailable orders.

<img width="1362" height="721" alt="Screenshot 2026-08-10 122506" src="https://github.com/user-attachments/assets/2567966d-78cc-4f2d-afaa-951a09ca7f31" />

## Categories/Product Analysis
On the category side, Sports, Toys & Leisure and Home & Furniture lead the pack. Fashion & Accessories finishes last — not only in revenue but also in units sold.
<img width="1365" height="742" alt="Screenshot 2026-08-10 132003" src="https://github.com/user-attachments/assets/633d789d-41e3-44c5-ab4e-36942bf2cc0d" />

## Seller Performance and Concentration
The seller base looks healthy. Revenue is well spread: the top 15 sellers out of more than 3,000 account for less than 20% of total revenue. Even more interesting are a handful of small cities that punch far above their weight. Guariba, with a single seller, generated nearly R$500,000. Lauro de Freitas, with only two sellers, was close behind. These “lucrative gaps” suggest product-market fit worth studying and replicating elsewhere.
<img width="1365" height="724" alt="Screenshot 2026-08-10 132725" src="https://github.com/user-attachments/assets/616d79ae-5f42-46a5-9f70-f1c99e06a90d" />

# Where the Friction Appears
## Customer Retention & Satisfaction
- The strongest finding in the entire analysis is also the most uncomfortable: 96.9% of customers place only one order. Just over 3% ever return for a second purchase, and fewer than 1% come back in a later calendar year. This one-and-done pattern sits underneath almost every other problem the data reveals.
- Customer satisfaction tells a related story. About one in seven reviews is negative. Delivery speed is the clearest driver of how customers feel. Orders that arrive in roughly two days average 4.38 stars; those that take a month fall to 3.55. Approval time, by contrast, barely moves the score at all.

## Product Phasing out
- Products show a similar lack of staying power. 85% of the catalog sells in only one year and then disappears. Stockouts and poor reviews do not explain the drop-off. The more likely cause is a deeper issue with demand, discovery, or the absence of reasons for customers to buy again.

## Order Cancellation
- Cancellations add another layer. Of the 625 cancelled orders, 65% happen after the order has been approved but before it ships. Customers describe items marked out of stock only after purchase, missing invoices, and long silences. Credit card customers carry most of the complaint burden — they pay first and wait longest for resolution.
<img width="1360" height="751" alt="Screenshot 2026-08-10 141945" src="https://github.com/user-attachments/assets/48062ce4-a826-4c91-a01f-fbcb9ea47176" />

## Payment types and Voucher Stacking
- Credit card is the dominant payment method behind cancellations, accounting for 444 of 625 cancelled orders (71%), compared to 189 (30%) for vouchers and just 7 (1%) for debit cards. This pattern carries through to complaints: credit card customers generate 76% of refund complaints (29 of 38) and 72% of invoice complaints (13 of 18) tied to cancelled orders — largely because they pay upfront and are left waiting longest for resolution when a seller fails to invoice or ship.
- Voucher usage shows a distinct pattern: discount-stacking. Voucher orders average 1.47 payments per order, versus 1.01 for credit card and 1.04 for debit card — meaning customers are commonly applying more than one voucher to a single purchase. This behavior sits apart from the cancellation and complaint trends above; it's a cash-flow consideration (lower net revenue per order) rather than a driver of order failures
  <img width="1361" height="745" alt="Screenshot 2026-08-10 143525" src="https://github.com/user-attachments/assets/51abde06-51a4-4c56-85fb-bf4080b2fdff" />

# Recommendations
- Fix the fulfillment gap first — tighten seller-side inventory accuracy and pre-approval stock checks; this is where 65% of cancellations originate.
- Prioritize delivery speed over approval speed — it's the stronger lever on review scores (4.38★ → 3.55★ across delivery buckets vs. a near-flat 4.10★ → 4.01★ across approval buckets).
- Build a retention program — even a small lift off the current 3.12% repeat-purchase rate has outsized impact given how low the baseline is.
- Study and replicate the "lucrative gap" cities (e.g., Guariba) — identify what's driving high revenue-per-seller there and test it in underperforming markets.
- Streamline refund/invoice handling for credit card orders — they carry the bulk of cancellation-related complaints and are waiting longest for resolution.
- Investigate Fashion & Accessories and general product churn as a follow-up study — current data (reviews, delivery time, stockouts) doesn't explain either, so the cause is likely demand-side, not operational.
- Flag the "after delivery" cancellation records to the source/ops team — they look like a data quality issue, not a real operational failure.    
  
# Assumptions
- Financial categorization: grouped order_status into In Our Books (delivered), Projected Earnings (approved/invoiced/processing/shipped), Canceled/Unavailable — a business-logic grouping, not a source field.
- Delivery/approval time buckets (e.g., "~2 days," "0–24 hrs") are manually chosen ranges for readability, not natural breakpoints in the data.
- Order lifecycle stage (no explicit "cancellation stage" field exists):
    -  Before approval → order_approved_at is null
    - After approval, never shipped → approved, but no carrier/delivery date
    -  During shipping → handed to carrier, but no delivery date
    -  After delivery → delivery date present despite "canceled" status — treated as a likely data/status-mapping error (some have positive reviews), not a genuine late cancellation.
       
The SQL queries created during the database exploration and data cleaning can be found [here]






