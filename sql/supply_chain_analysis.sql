use supply_chain_analysis;

-- Q1. Revenue by product type

select
p.ProductType,
sum(f.UnitsSold) total_units_sold,
Round(sum(f.Revenue),2) total_revenue
from factsupplychain f
join dimproduct p on f.`Product ID` = p.`Product ID`
group by p.ProductType
order by total_revenue desc
;

-- Q2. Pareto: how many SKUs drive 80% of revenue?

with sku_revenue as (
    select p.SKU, p.ProductType, sum(f.Revenue) as revenue
    from factsupplychain f
    join dimproduct p on f.`Product ID` = p.`Product ID`
    group by p.SKU, p.ProductType
)
select
    SKU,
    ProductType,
    ROUND(revenue, 2) as revenue,
    rank() over (order by revenue desc) as revenue_rank,
    ROUND(100.0 * sum(revenue) over (order by revenue desc
          rows unbounded preceding) / sum(revenue) over (), 1) as cumulative_share_pct
from sku_revenue
order by revenue desc;

-- Q3. Supplier risk scorecard

with supplier_stats as (
    select
        SupplierName,
        avg(DefectRate) as avg_defect_rate,
        avg(SupplierLeadTime) as avg_lead_time,
        avg(case when InspectionResult = 'Fail' then 1.0 else 0 end) as fail_rate
    from dimsupplier
    group by SupplierName
)
select
    SupplierName,
    ROUND(avg_defect_rate, 2) as avg_defect_rate,
    ROUND(avg_lead_time, 1) as avg_lead_time_days,
    ROUND(100 * fail_rate, 1) as inspection_fail_pct,
    ROUND(100 * (
          0.4 * percent_rank() over (order by avg_defect_rate)
        + 0.3 * percent_rank() over (order by avg_lead_time)
        + 0.3 * percent_rank() over (order by fail_rate)
    ), 1) as risk_score
from supplier_stats
order by risk_score desc;

-- Q4. Stock-out risk by SKU

with sku_stock as (
    select
        p.SKU,
        p.ProductType,
        f.StockLevel,
        f.OrderQty,
        f.LeadTime,
        f.Revenue,
        case
            when f.StockLevel < 0.5 * f.OrderQty then 'High'
            when f.StockLevel < f.OrderQty then 'Medium'
            else 'Low'
        end as stockout_risk
    from factsupplychain f
    join dimproduct p on f.`Product ID` = p.`Product ID`
)
select
    stockout_risk,
    COUNT(*) as sku_count,
    ROUND(SUM(Revenue), 2) as revenue_at_risk,
    ROUND(AVG(LeadTime), 1) as avg_lead_time_days
from sku_stock
group by stockout_risk
order by case stockout_risk when 'High' then 1 when 'Medium' then 2 else 3 end;

-- Q5. Carrier and transport mode: cost vs speed

with carrier_stats as (
    select
        sh.Carrier,
        sh.TransportMode,
        COUNT(*) as shipments,
        avg(f.ShippingCost) as avg_shipping_cost,
        avg(f.ShippingTime) as avg_shipping_time
    from factsupplychain f
    join dimshipping sh on f.`Shipping ID` = sh.`Shipping ID`
    group by sh.Carrier, sh.TransportMode
)
select
    Carrier,
    TransportMode,
    shipments,
    ROUND(avg_shipping_cost, 2) as avg_shipping_cost,
    ROUND(avg_shipping_time, 1) as avg_shipping_time_days,
    rank() over (order by avg_shipping_cost) as cost_rank,
    rank() over (order by avg_shipping_time) as speed_rank
from carrier_stats
order by cost_rank;

-- Q6. Inspection Result Summary (Quality Control) --

select 
s.InspectionResult,
count(*) as count,
round(count(*) * 100.0 / (select count(*) from dimsupplier),1 ) as Percentage
from dimsupplier s
group by s.InspectionResult
order by count desc;

-- Q7. Revenue by Supplier Location 

select
s.SupplierLocation,
count(f.`Product ID`) sku_count,
Round(sum(f.Revenue),2) total_revenue,
Round(avg(f.UnitsSold),0) avg_units_sold
from factsupplychain f
join dimsupplier s on f.`Supplier ID` = s.`Supplier ID`
group by s.SupplierLocation
order by total_revenue desc;
