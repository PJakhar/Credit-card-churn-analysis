-- =====================================================
-- 02_segments.sql
-- Churn rate by customer segment, with 95% confidence ranges
-- Bank average churn: 16.1% (1,627 of 10,127)
-- =====================================================


-- Query 1: Churn rate for every segment, with Wilson confidence
-- ranges and a verdict vs the bank average

WITH long AS (
  SELECT 'Gender' AS dimension, Gender AS segment, Attrition_Flag FROM `churn-portfolio.Churn.Customers`
  UNION ALL SELECT 'Card', Card_Category, Attrition_Flag FROM `churn-portfolio.Churn.Customers`
  UNION ALL SELECT 'Income', Income_Category, Attrition_Flag FROM `churn-portfolio.Churn.Customers`
  UNION ALL SELECT 'Education', Education_Level, Attrition_Flag FROM `churn-portfolio.Churn.Customers`
  UNION ALL SELECT 'Marital', Marital_Status, Attrition_Flag FROM `churn-portfolio.Churn.Customers`
  UNION ALL SELECT 'Age band',
    CASE WHEN Customer_Age < 35 THEN '26-34'
         WHEN Customer_Age < 45 THEN '35-44'
         WHEN Customer_Age < 55 THEN '45-54'
         ELSE '55+' END,
    Attrition_Flag FROM `churn-portfolio.Churn.Customers`
),
seg AS (
  SELECT dimension, segment, COUNT(*) AS n,
         COUNTIF(Attrition_Flag = 'Attrited Customer') AS churned
  FROM long
  GROUP BY dimension, segment
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
  dimension, segment, n, churned,
  ROUND(p, 3) AS churn_rate,
  ROUND(lo, 3) AS ci_low,
  ROUND(hi, 3) AS ci_high,
  CASE WHEN lo > 0.161 THEN 'Higher'
       WHEN hi < 0.161 THEN 'Lower'
       ELSE 'No clear difference' END AS vs_bank
FROM ci
ORDER BY dimension, churn_rate DESC;

-- FINDINGS:
-- * Only 4 of 27 segments differ from the bank average.
--   Demographics are weak predictors of churn.
-- * Women 17.4% (Higher), men 14.6% (Lower). Large groups,
--   ranges don't overlap: the only solid demographic signal.
-- * Card tier shows no difference. Platinum's 25% is just
--   5 of 20 customers (range 11%-47%), so it's noise.
-- * Doctorate 21.1% (Higher) and $60K-$80K 13.5% (Lower) are
--   borderline. With 27 tests, ~1 false flag is expected by chance.
-- * Age, marital status and most education/income levels:
--   no clear difference.
-- * Next: behaviour (activity changes, inactivity, contacts)
--   is the more likely churn driver.


-- Query 2: Gender x income check
-- Is the gender gap really an income effect in disguise?

SELECT
  Income_Category,
  Gender,
  COUNT(*) AS n,
  ROUND(COUNTIF(Attrition_Flag = 'Attrited Customer') / COUNT(*), 3) AS churn_rate
FROM `churn-portfolio.Churn.Customers`
GROUP BY Income_Category, Gender
ORDER BY Income_Category, Gender;

-- FINDINGS:
-- * No women above $60K in the data. All $60K+ customers are men.
--   This is a dataset quirk, not a real-world pattern.
-- * So the $60K-$80K "Lower" flag is really a male effect.
-- * Within shared income bands, women churn more in every one:
--   <$40K 17.7% vs 10.8%, $40K-$60K 16.4% vs 13.5%,
--   Unknown 17.2% vs 9.6%. Male groups are small in two bands.
-- * Verdict: women churn somewhat more even at similar incomes,
--   but gender and income can't be fully separated here.
--   Treat gender as a weak signal, not a targeting rule.
