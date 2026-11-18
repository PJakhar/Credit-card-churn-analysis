-- =====================================================
-- 03_signals.sql
-- Behavioural early-warning signals for churn
-- Bank average churn: 16.1%
-- =====================================================


-- Query 1: Average behaviour of churners vs stayers

SELECT
  Attrition_Flag,
  COUNT(*) AS n,
  ROUND(AVG(Total_Ct_Chng_Q4_Q1), 3)    AS avg_count_change,
  ROUND(AVG(Total_Amt_Chng_Q4_Q1), 3)   AS avg_amount_change,
  ROUND(AVG(Total_Trans_Ct), 1)         AS avg_txn_count,
  ROUND(AVG(Total_Trans_Amt), 0)        AS avg_spend,
  ROUND(AVG(Months_Inactive_12_mon), 2) AS avg_inactive_months,
  ROUND(AVG(Contacts_Count_12_mon), 2)  AS avg_contacts,
  ROUND(AVG(Total_Relationship_Count), 2) AS avg_products,
  ROUND(AVG(Total_Revolving_Bal), 0)    AS avg_revolving_bal,
  ROUND(AVG(Avg_Utilization_Ratio), 3)  AS avg_utilisation
FROM `churn-portfolio.Churn.Customers`
GROUP BY Attrition_Flag;

-- FINDINGS:
-- * Strong gaps: churners make 45 vs 69 transactions a year,
--   their Q4/Q1 transaction count ratio is 0.55 vs 0.74,
--   they carry about half the revolving balance (673 vs 1,257),
--   and hold fewer products (3.3 vs 3.9).
-- * Moderate: churners contact the bank more (3.0 vs 2.4)
--   and are inactive slightly longer (2.7 vs 2.3 months).
-- * Weak: spend amount change (0.69 vs 0.77). Transaction COUNT
--   dropping is a better warning than spend AMOUNT dropping.
-- * Caution: 12-month totals are partly a symptom of leaving
--   (closed cards stop transacting). The Q4/Q1 ratio is closer
--   to a true early warning.


-- Query 2: Churn by transaction count change (Q4/Q1), in bands

WITH banded AS (
  SELECT
    CASE WHEN Total_Ct_Chng_Q4_Q1 < 0.4 THEN '1: under 0.4'
         WHEN Total_Ct_Chng_Q4_Q1 < 0.6 THEN '2: 0.4-0.6'
         WHEN Total_Ct_Chng_Q4_Q1 < 0.8 THEN '3: 0.6-0.8'
         WHEN Total_Ct_Chng_Q4_Q1 < 1.0 THEN '4: 0.8-1.0'
         ELSE '5: 1.0 and up' END AS band,
    Attrition_Flag
  FROM `churn-portfolio.Churn.Customers`
),
seg AS (
  SELECT band, COUNT(*) AS n,
         COUNTIF(Attrition_Flag = 'Attrited Customer') AS churned
  FROM banded
  GROUP BY band
),
rates AS (
  SELECT *, churned / n AS p FROM seg
),
ci AS (
  SELECT *,
    (p + 3.8416/(2*n) - 1.96*SQRT(p*(1-p)/n + 3.8416/(4*n*n))) / (1 + 3.8416/n) AS lo,
    (p + 3.8416/(2*n) + 1.96*SQRT(p*(1-p)/n + 3.8416/(4*n*n))) / (1 + 3.8416/n) AS hi
  FROM rates
)
SELECT
  band, n, churned,
  ROUND(p, 3) AS churn_rate,
  ROUND(lo, 3) AS ci_low,
  ROUND(hi, 3) AS ci_high,
  CASE WHEN lo > 0.161 THEN 'Higher'
       WHEN hi < 0.161 THEN 'Lower'
       ELSE 'No clear difference' END AS vs_bank
FROM ci
ORDER BY band;

-- FINDINGS:
-- * Clear cliff at 0.6. Under 0.4: 60% churn. 0.4-0.6: 28.5%.
--   Above 0.6: only 7-9%.
-- * Customers under 0.6 are 28% of the base (2,808) but hold
--   62% of all churners (1,006 of 1,627).
-- * Threshold for risk score: count change under 0.6.


-- Query 3: Churn by inactive months, contacts and products held

WITH long AS (
  SELECT 'Inactive months' AS dimension, Months_Inactive_12_mon AS band, Attrition_Flag FROM `churn-portfolio.Churn.Customers`
  UNION ALL SELECT 'Contacts', Contacts_Count_12_mon, Attrition_Flag FROM `churn-portfolio.Churn.Customers`
  UNION ALL SELECT 'Products held', Total_Relationship_Count, Attrition_Flag FROM `churn-portfolio.Churn.Customers`
),
seg AS (
  SELECT dimension, band, COUNT(*) AS n,
         COUNTIF(Attrition_Flag = 'Attrited Customer') AS churned
  FROM long
  GROUP BY dimension, band
),
rates AS (
  SELECT *, churned / n AS p FROM seg
),
ci AS (
  SELECT *,
    (p + 3.8416/(2*n) - 1.96*SQRT(p*(1-p)/n + 3.8416/(4*n*n))) / (1 + 3.8416/n) AS lo,
    (p + 3.8416/(2*n) + 1.96*SQRT(p*(1-p)/n + 3.8416/(4*n*n))) / (1 + 3.8416/n) AS hi
  FROM rates
)
SELECT
  dimension, band, n, churned,
  ROUND(p, 3) AS churn_rate,
  ROUND(lo, 3) AS ci_low,
  ROUND(hi, 3) AS ci_high,
  CASE WHEN lo > 0.161 THEN 'Higher'
       WHEN hi < 0.161 THEN 'Lower'
       ELSE 'No clear difference' END AS vs_bank
FROM ci
ORDER BY dimension, band;

-- FINDINGS:
-- * Contacts: churn rises steadily, from 1.8% (0 contacts) to
--   33.5% (5 contacts). All 54 customers with 6 contacts churned,
--   likely leakage: the last contact is probably the cancellation
--   request itself. Threshold: 3+ contacts.
-- * Inactive months: risk peaks at 3-4 months (21.5%, 29.9%),
--   then returns to average at 5-6 months (small groups).
--   1 month inactive is very safe (4.5%). The 0-month group
--   (29 people, 51.7%) is too small to trust.
--   Threshold: 3+ inactive months.
-- * Products held: 1-2 products churn at 26-28%, 4-6 products
--   at 10-12%. More products = stickier customers.
--   Threshold: 2 or fewer products.
