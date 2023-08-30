-- Databricks notebook source
CREATE WIDGET TEXT database DEFAULT "main.default"

-- COMMAND ----------

-- MAGIC %sql
-- MAGIC SELECT * FROM ${database}.silver_transactions LIMIT 5

-- COMMAND ----------

-- MAGIC %sql
-- MAGIC CREATE OR REPLACE TABLE ${database}.gold_aggregated_transactions AS
-- MAGIC SELECT t.* EXCEPT(countryOrig, countryDest, is_fraud), c.* EXCEPT(id),
-- MAGIC           boolean(coalesce(is_fraud, 0)) as is_fraud,
-- MAGIC           o.alpha3_code as countryOrig, o.country as countryOrig_name, o.long_avg as countryLongOrig_long, o.lat_avg as countryLatOrig_lat,
-- MAGIC           d.alpha3_code as countryDest, d.country as countryDest_name, d.long_avg as countryLongDest_long, d.lat_avg as countryLatDest_lat
-- MAGIC FROM ${database}.silver_transactions t
-- MAGIC   INNER JOIN ${database}.silver_country_coordinates o ON t.countryOrig=o.alpha3_code 
-- MAGIC   INNER JOIN ${database}.silver_country_coordinates d ON t.countryDest=d.alpha3_code 
-- MAGIC   INNER JOIN ${database}.silver_customers c ON c.id=t.customer_id 

-- COMMAND ----------

-- MAGIC %sql
-- MAGIC SELECT * FROM ${database}.gold_aggregated_transactions LIMIT 5

-- COMMAND ----------


