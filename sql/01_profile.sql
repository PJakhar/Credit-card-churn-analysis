-- 1. Row count and unique customers (should match)
SELECT COUNT(*) AS rows_, COUNT(DISTINCT CLIENTNUM) AS customers
FROM churn.customers;
-- 2. Overall churn rate
SELECT Attrition_Flag, COUNT(*) AS n,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 3) AS share
FROM churn.customers
GROUP BY Attrition_Flag;
-- 3. "Unknown" values in categoricals
SELECT
  COUNTIF(Education_Level = 'Unknown') AS edu_unknown,
  COUNTIF(Marital_Status = 'Unknown')  AS marital_unknown,
  COUNTIF(Income_Category = 'Unknown') AS income_unknown
FROM churn.customers;
-- 4. Category sizes (rerun swapping Card_Category for Gender, then Income_Category)
SELECT Card_Category, COUNT(*) AS n
FROM churn.customers
GROUP BY Card_Category
ORDER BY n DESC;
-- 5. Numeric ranges
SELECT
  MIN(Customer_Age) AS min_age, MAX(Customer_Age) AS max_age,
  MIN(Credit_Limit) AS min_limit, MAX(Credit_Limit) AS max_limit,
  ROUND(AVG(Total_Trans_Ct), 1) AS avg_txn_count,
  ROUND(AVG(Avg_Utilization_Ratio), 3) AS avg_util
FROM churn.customers;
