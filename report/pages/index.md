---
title: Olist E-Commerce Report
---

Built with [dbt](https://github.com/SebManley/data-pipeline-dbt) on the full Olist Brazilian
E-Commerce dataset (~100k orders, 2016–2018), rendered as a static site with
[Evidence](https://evidence.dev). Source: `marts.fct_daily_revenue`, `marts.fct_orders`,
`marts.dim_customers`, `marts.fct_product_category_revenue`.

<Alert status=info>
Data covers 2016-09 through 2018-08. The source dataset's final ~6 weeks contain only a
sparse trailing sample rather than complete data, so orders placed on/after 2018-09-01 are
excluded from all marts to avoid a misleading drop-off in the trend charts below.
</Alert>

## Overview

```sql revenue_overview
SELECT
  SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END)                                  AS total_delivered_orders,
  ROUND(SUM(CASE WHEN NOT is_cancelled THEN order_total ELSE 0 END)::NUMERIC, 2) AS total_revenue,
  ROUND(AVG(CASE WHEN NOT is_cancelled THEN order_total END)::NUMERIC, 2)        AS avg_order_value
FROM fct_orders
```

```sql customer_overview
SELECT
  ROUND(SUM(CASE WHEN is_repeat_customer THEN 1 ELSE 0 END)::NUMERIC / COUNT(*), 4) AS repeat_rate_pct
FROM dim_customers
```

<Grid cols={4}>
<BigValue data={revenue_overview} value=total_delivered_orders fmt=num0 title="Total Delivered Orders"/>
<BigValue data={revenue_overview} value=avg_order_value fmt=usd2 title="Average Order Value"/>
<BigValue data={revenue_overview} value=total_revenue fmt=usd0 title="Total Revenue"/>
<BigValue data={customer_overview} value=repeat_rate_pct fmt=pct1 title="Repeat Customer Rate"/>
</Grid>

```sql monthly_revenue
SELECT
  DATE_TRUNC('month', order_date) AS month,
  SUM(gross_revenue)              AS gross_revenue,
  SUM(order_count)                AS order_count
FROM fct_daily_revenue
GROUP BY 1
ORDER BY 1
```

<Grid cols={2}>
<LineChart
    data={monthly_revenue}
    x=month
    y=gross_revenue
    title="Revenue Over Time"
    subtitle="Monthly, excl. cancelled"
    yFmt=usd0
/>
<BarChart
    data={monthly_revenue}
    x=month
    y=order_count
    title="Order Volume by Month"
    subtitle="Monthly, excl. cancelled"
/>
</Grid>

```sql customer_segments
SELECT
  CASE WHEN is_repeat_customer THEN 'Repeat' ELSE 'One-Time' END AS segment,
  COUNT(*)                                                       AS customer_count
FROM dim_customers
GROUP BY 1
```

<BarChart
    data={customer_segments}
    x=segment
    y=customer_count
    title="Repeat vs One-Time Customers"
    swapXY=true
/>

## Product Category Performance

```sql top_categories
SELECT
  product_category,
  revenue,
  order_count
FROM fct_product_category_revenue
ORDER BY revenue DESC
LIMIT 10
```

<BarChart
    data={top_categories}
    x=product_category
    y=revenue
    title="Top 10 Categories by Revenue"
    yFmt=usd0
    swapXY=true
/>

```sql all_categories
SELECT
  product_category,
  order_count,
  item_count,
  revenue
FROM fct_product_category_revenue
ORDER BY revenue DESC
```

All 74 categories:

<DataTable data={all_categories} rows={10} search={true}>
    <Column id=product_category title="Category"/>
    <Column id=order_count title="Orders"/>
    <Column id=item_count title="Items Sold"/>
    <Column id=revenue title="Revenue" fmt=usd0/>
</DataTable>

## Order Performance

```sql order_kpis
SELECT
  ROUND(SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END)::NUMERIC / COUNT(*), 4)   AS delivery_rate_pct,
  ROUND(SUM(CASE WHEN is_cancelled THEN 1 ELSE 0 END)::NUMERIC / COUNT(*), 4)   AS cancellation_rate_pct,
  ROUND(AVG(days_to_deliver), 1)                                               AS avg_days_to_deliver,
  ROUND(
    SUM(CASE WHEN delivered_on_time THEN 1 ELSE 0 END)::NUMERIC
    / NULLIF(SUM(CASE WHEN delivered_on_time IS NOT NULL THEN 1 ELSE 0 END), 0), 4
  ) AS on_time_rate_pct
FROM fct_orders
```

<Grid cols={4}>
<BigValue data={order_kpis} value=delivery_rate_pct fmt=pct1 title="Delivery Rate"/>
<BigValue data={order_kpis} value=on_time_rate_pct fmt=pct1 title="On-Time Rate"/>
<BigValue data={order_kpis} value=cancellation_rate_pct fmt=pct1 title="Cancellation Rate"/>
<BigValue data={order_kpis} value=avg_days_to_deliver fmt=num1 title="Avg Days to Deliver"/>
</Grid>

```sql order_status_breakdown
SELECT
  order_status,
  COUNT(*) AS order_count
FROM fct_orders
GROUP BY order_status
ORDER BY order_count DESC
```

```sql delivery_times
SELECT days_to_deliver
FROM fct_orders
WHERE is_delivered AND days_to_deliver BETWEEN 0 AND 60
```

<Grid cols={2}>
<BarChart
    data={order_status_breakdown}
    x=order_status
    y=order_count
    title="Orders by Status"
    swapXY=true
/>
<Histogram
    data={delivery_times}
    x=days_to_deliver
    title="Delivery Time Distribution"
    subtitle="Capped at 60 days (p99 = 46)"
    xAxisTitle="Days to deliver"
/>
</Grid>

## Customer Insights

```sql ltv_by_state
SELECT
  state_code,
  ROUND(SUM(lifetime_value)::NUMERIC, 2) AS total_ltv,
  COUNT(*)                               AS customer_count
FROM dim_customers
GROUP BY state_code
ORDER BY total_ltv DESC
LIMIT 10
```

```sql new_customers_monthly
SELECT
  DATE_TRUNC('month', first_order_at) AS month,
  COUNT(*)                            AS new_customers
FROM dim_customers
WHERE first_order_at IS NOT NULL
GROUP BY 1
ORDER BY 1
```

<Grid cols={2}>
<BarChart
    data={ltv_by_state}
    x=state_code
    y=total_ltv
    title="Lifetime Value by State (Top 10)"
    yFmt=usd0
    swapXY=true
/>
<LineChart
    data={new_customers_monthly}
    x=month
    y=new_customers
    title="New Customer Acquisition"
    subtitle="First-time customers per month"
/>
</Grid>
